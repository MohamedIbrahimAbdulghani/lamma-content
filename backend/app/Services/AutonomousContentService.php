<?php
// Lamma - by Mohamed Ibrahim

namespace App\Services;

use App\Helpers\ArabicNormalizer;
use App\Models\Category;
use App\Models\Question;
use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class AutonomousContentService
{
    protected GenerateAiContentService $ai;
    protected ContentVerificationService $verifier;
    protected const DAILY_LIMIT = 500;

    public function __construct(GenerateAiContentService $ai, ContentVerificationService $verifier)
    {
        $this->ai = $ai;
        $this->verifier = $verifier;
    }

    /**
     * التحقق من عدم تجاوز سقف التكلفة اليومي للذكاء الاصطناعي
     */
    public function canMakeAiRequest(): bool
    {
        $todayKey = 'lamma_ai_daily_usage_' . date('Y-m-d');
        $currentCount = (int) Cache::get($todayKey, 0);
        return $currentCount < self::DAILY_LIMIT;
    }

    public function incrementAiUsage(): void
    {
        $todayKey = 'lamma_ai_daily_usage_' . date('Y-m-d');
        $count = (int) Cache::get($todayKey, 0);
        Cache::put($todayKey, $count + 1, now()->endOfDay());
    }

    public function getDailyUsageStats(): array
    {
        $todayKey = 'lamma_ai_daily_usage_' . date('Y-m-d');
        $currentCount = (int) Cache::get($todayKey, 0);
        return [
            'used_today' => $currentCount,
            'daily_limit' => self::DAILY_LIMIT,
            'remaining' => max(0, self::DAILY_LIMIT - $currentCount),
        ];
    }

    // =========================================================================
    // 1. توليد أسئلة تحدي الشلة (توليد + فلترة صارمة + تحقق أعمى + مدقق مراجعة)
    // =========================================================================

    public function generateTriviaQuestions(string $categorySlug, string $difficulty = 'medium', int $count = 8): array
    {
        if (!$this->canMakeAiRequest()) {
            Log::warning('AutonomousContentService: Daily AI quota reached. Skipping trivia generation.');
            return ['generated' => 0, 'approved' => 0, 'rejected' => 0, 'reasons' => ['سقف الاستخدام اليومي ممتلئ']];
        }

        $canonicalSlug = Category::canonicalSlug($categorySlug);
        $category = Category::where('slug', $canonicalSlug)->first();
        if (!$category) {
            $category = Category::where('is_active', true)->where('slug', '!=', 'nokat')->first();
            $canonicalSlug = $category?->slug ?? 'general';
        }

        $catDef = ContentVerificationService::CATEGORY_DEFINITIONS[$canonicalSlug] ?? ContentVerificationService::CATEGORY_DEFINITIONS['general'];

        // توليد مخزون أكبر لتعويض المرفوض بالتحقق الصارم
        $requestCount = max(6, (int) ceil($count * 1.5));

        $prompt = <<<EOT
أنت صانع أسئلة مسابقات مصري محترف لتطبيق 'لمّة' ولعبة 'تحدي الشلة'.
المطلوب: توليد قائمة من {$requestCount} أسئلة اختيار من متعدد في قسم [{$catDef['name_ar']}] ومستوى صعوبة [{$difficulty}].

حدود ونطاق هذا القسم حصراً:
- النطاق المسموح: {$catDef['scope']}
- الممنوع في هذا القسم: {$catDef['not_allowed']}

شروط جودة وموثوقية صارمة لا تقبل التهاون:
1. السؤال عن **حقائق ثابتة ومعروفة تاريخياً وعلمياً فقط**.
2. ممنوع منعاً باتاً:
   - الأرقام الدقيقة المتغيرة أو الأرقام القياسية الحديثة (مثل: الهداف التاريخي، أرقام البطولات الحديثة، الأسعار).
   - الأسئلة الزمنية ("حالياً"، "الآن"، "الأحدث"، "المدرب الحالي").
   - الآراء والتقييمات الشخصية ("أفضل فيلم"، "أشهر أغنية").
   - الأسئلة المركبة (سؤالان في سؤال).
   - الأسئلة الغامضة أو التي تحتمل أكثر من إجابة صحيحة.
3. 4 خيارات لكل سؤال:
   - متجانسة تماماً ومن نفس الفئة ونفس الطول الواقعي.
   - الخيارات الثلاثة الخاطئة خاطئة قطعاً ويقيناً.
   - خيارات فريدة ولا تحتوي على نص السؤال.
   - ممنوع خيارات مثل "كل ما سبق" أو "لا شيء مما سبق".
4. توزيع correct_index عشوائياً بين 0 و 3 بتوازن.

الرد بصيغة JSON array فقط:
[
  {
    "prompt_ar": "نص السؤال الدقيق هنا؟",
    "options": ["خيار 1", "خيار 2", "خيار 3", "خيار 4"],
    "correct_index": 0,
    "category_slug": "{$canonicalSlug}",
    "difficulty": "{$difficulty}",
    "explanation_ar": "توضيح تاريخي مختصر وموثق"
  }
]
EOT;

        $rawResponse = $this->ai->generateRawContent($prompt, [
            'temperature' => 0.3,
            'maxOutputTokens' => 2048,
        ]);
        $this->incrementAiUsage();

        $candidates = $this->parseJsonArray($rawResponse);
        if (empty($candidates)) {
            return ['generated' => 0, 'approved' => 0, 'rejected' => 0, 'reasons' => ['فشل في معالجة الرد بتنسيق JSON']];
        }

        $approvedCount = 0;
        $rejectedCount = 0;
        $rejectionReasons = [];

        $existingPrompts = Question::where('category_id', $category->id)
            ->where('status', 'active')
            ->pluck('normalized_prompt')
            ->filter()
            ->all();

        $batchPrompts = [];

        foreach ($candidates as $item) {
            if ($approvedCount >= $count) {
                break;
            }

            if (!isset($item['prompt_ar'], $item['options'], $item['correct_index'])) {
                $rejectedCount++;
                $rejectionReasons[] = 'بنية السؤال غير مكتملة';
                continue;
            }

            $promptAr = trim((string) $item['prompt_ar']);
            $options = (array) $item['options'];
            $cIndex = (int) $item['correct_index'];

            // 1. الفحوصات الآلية البرمجية الصارمة
            $autoCheck = $this->verifier->runAutomatedChecks($promptAr, $options, $cIndex);
            if (!$autoCheck['passed']) {
                $rejectedCount++;
                $rejectionReasons[] = 'فحص آلي: ' . $autoCheck['reason'];
                continue;
            }

            $normPrompt = ArabicNormalizer::normalize($promptAr);

            // 2. منع التكرار بالبصمة وتشابه الصياغة
            $pHash = ArabicNormalizer::promptHash($promptAr);
            $correctOpt = trim($options[$cIndex]);
            $aHash = ArabicNormalizer::answerHash($canonicalSlug, $correctOpt);

            if (Question::where('prompt_hash', $pHash)->exists() ||
                Question::where('answer_hash', $aHash)->where('category_id', $category->id)->exists()) {
                $rejectedCount++;
                $rejectionReasons[] = 'السؤال أو الإجابة مكررة في قاعدة البيانات';
                continue;
            }

            if (in_array($normPrompt, $batchPrompts, true)) {
                $rejectedCount++;
                $rejectionReasons[] = 'السؤال مكرر في نفس الدفعة';
                continue;
            }

            $isTooSimilar = false;
            foreach ($existingPrompts as $ex) {
                if (ArabicNormalizer::jaccardSimilarity($normPrompt, $ex) >= 0.65) {
                    $isTooSimilar = true;
                    break;
                }
            }
            if ($isTooSimilar) {
                $rejectedCount++;
                $rejectionReasons[] = 'صياغة السؤال شديدة الشبه بسؤال سابق';
                continue;
            }

            // 3. التحقق الأعمى المستقل (Blind Verification) + مدقق المراجعة والتصنيف
            if (!$this->canMakeAiRequest()) {
                // قاعدة صارمة: لا مسار "ثق بالـ AI" إذا نفد السقف أو تعذر التحقق
                $rejectedCount++;
                $rejectionReasons[] = 'تعذر التحقق بسبب سقف الاستخدام - رفض احترازي';
                continue;
            }

            $verification = $this->verifier->verifyTriviaQuestion(
                prompt: $promptAr,
                options: $options,
                correctIndex: $cIndex,
                categorySlug: $canonicalSlug,
                difficulty: $difficulty
            );

            if (!$verification['approved']) {
                $rejectedCount++;
                $rejectionReasons[] = 'رفض التحقق المستقل: ' . ($verification['reason'] ?? 'عدم تطابق معايير الدقة');
                continue;
            }

            // 4. السؤال اجتاز جميع الطبقات بنجاح تام -> حفظه ونشره
            $distractors = $options;
            unset($distractors[$cIndex]);
            sort($distractors);
            $dHash = hash('sha256', implode('|', array_map([ArabicNormalizer::class, 'normalize'], $distractors)));

            Question::create([
                'category_id' => $category->id,
                'type' => 'mcq',
                'prompt_ar' => $promptAr,
                'normalized_prompt' => $normPrompt,
                'options' => array_values($options),
                'correct_index' => $cIndex,
                'difficulty' => in_array($difficulty, ['easy', 'medium', 'hard']) ? $difficulty : 'medium',
                'explanation_ar' => $item['explanation_ar'] ?? null,
                'source' => 'gemini',
                'content_hash' => Question::makeContentHash($promptAr),
                'prompt_hash' => $pHash,
                'answer_hash' => $aHash,
                'distractors_hash' => $dHash,
                'status' => 'active',
                'is_active' => true,
                'published_at' => now(),
            ]);

            $batchPrompts[] = $normPrompt;
            $existingPrompts[] = $normPrompt;
            $approvedCount++;
        }

        return [
            'generated' => count($candidates),
            'approved' => $approvedCount,
            'rejected' => $rejectedCount,
            'reasons' => array_values(array_unique($rejectionReasons)),
        ];
    }

    // =========================================================================
    // 2. توليد مجموعات كلمات الجاسوس المتجانسة بدقة (Spy Word Groups)
    // =========================================================================

    public function generateSpyWordGroup(string $packSlug = 'places', string $difficulty = 'medium'): array
    {
        if (!$this->canMakeAiRequest()) {
            return ['success' => false, 'error' => 'سقف الاستخدام اليومي ممتلئ'];
        }

        $canonicalPack = ($packSlug === 'food') ? 'foods' : $packSlug;
        $existingTitles = SpyWordGroup::where('pack_slug', $canonicalPack)->pluck('title_ar')->all();
        $existingTitlesStr = implode('، ', array_slice($existingTitles, -10));

        $packDesc = match ($canonicalPack) {
            'foods' => 'أكلات ومأكولات وحلويات ومشروبات مصرية مشهورة',
            'movies' => 'أعمال فنية وأفلام ومسرحيات ومسلسلات مصرية شهيرة',
            default => 'أماكن ومعالم وشوارع ومحافظات وميادين مصرية معروفة',
        };

        $prompt = <<<EOT
أنت مصمم للعبة "مين الجاسوس" المصرية.
قم بتوليد **مجموعة كلمات مترابطة ومتجانسة بدقة بالغة** (Word Group) في فئة [{$canonicalPack}] ({$packDesc}) ومستوى صعوبة [{$difficulty}].

شروط حاسمة:
1. المجموعة يجب أن تكون متجانسة تماماً من نفس الفئة المعرفية ونفس مستوى التحديد (مثال: إذا كانت معالم، فكلها معالم؛ إذا كانت مدن، فكلها مدن؛ إذا كانت حلويات، فكلها حلويات).
2. ممنوع إدخال كلمات من فئات أخرى (ممنوع إدخال طعام في الأماكن، أو أفلام في الأكلات).
3. تجنب تكرار هذه العناوين الموجودة مسبقاً: [{$existingTitlesStr}].

الرد بصيغة JSON فقط:
{
  "title_ar": "عنوان المجموعة الدقيق",
  "theme": "الموضوع العام",
  "difficulty": "{$difficulty}",
  "words": [
    "كلمة 1", "كلمة 2", "كلمة 3", "كلمة 4", "كلمة 5",
    "كلمة 6", "كلمة 7", "كلمة 8", "كلمة 9", "كلمة 10"
  ]
}
EOT;

        $rawResponse = $this->ai->generateRawContent($prompt, [
            'temperature' => 0.3,
            'maxOutputTokens' => 1024,
        ]);
        $this->incrementAiUsage();

        $data = json_decode($this->cleanJsonString($rawResponse), true);
        if (!isset($data['title_ar'], $data['words']) || !is_array($data['words'])) {
            return ['success' => false, 'error' => 'بنية المجموعة غير صالحة'];
        }

        $words = array_values(array_unique(array_filter(array_map('trim', $data['words']))));
        if (count($words) < 6) {
            return ['success' => false, 'error' => 'عدد الكلمات الصالحة في المجموعة أقل من 6'];
        }

        $titleAr = trim($data['title_ar']);
        $hash = SpyWordGroup::makeContentHash($titleAr, $words);

        if (SpyWordGroup::where('content_hash', $hash)->exists()) {
            return ['success' => false, 'error' => 'المجموعة مكررة بالفعل'];
        }

        $group = SpyWordGroup::create([
            'pack_slug' => $canonicalPack,
            'title_ar' => $titleAr,
            'theme' => $data['theme'] ?? $titleAr,
            'difficulty' => in_array($difficulty, ['easy', 'medium', 'hard']) ? $difficulty : 'medium',
            'status' => 'active',
            'content_hash' => $hash,
            'source' => 'gemini',
        ]);

        foreach ($words as $word) {
            $norm = mb_strtolower(trim($word));
            $wHash = hash('sha256', $norm);
            SpyGroupWord::create([
                'group_id' => $group->id,
                'word_ar' => $word,
                'normalized_word' => $norm,
                'content_hash' => $wHash,
            ]);
        }

        return [
            'success' => true,
            'group_id' => $group->id,
            'title_ar' => $titleAr,
            'words_count' => count($words),
        ];
    }

    // =========================================================================
    // 3. مساعدة ومعالجة نصوص JSON
    // =========================================================================

    protected function cleanJsonString(string $raw): string
    {
        $raw = trim($raw);
        if (preg_match('/```json\s*(.*?)\s*```/s', $raw, $matches)) {
            $raw = $matches[1];
        } elseif (preg_match('/```\s*(.*?)\s*```/s', $raw, $matches)) {
            $raw = $matches[1];
        }
        return trim($raw);
    }

    protected function parseJsonArray(string $raw): array
    {
        $cleaned = $this->cleanJsonString($raw);
        $decoded = json_decode($cleaned, true);
        if (is_array($decoded)) {
            return isset($decoded[0]) ? $decoded : [$decoded];
        }
        return [];
    }
}
