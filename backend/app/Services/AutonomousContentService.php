<?php
// Lamma - by Mohamed Ibrahim

namespace App\Services;

use App\Helpers\ArabicNormalizer;
use App\Models\Category;
use App\Models\CharadesCategory;
use App\Models\CharadesWord;
use App\Models\Question;
use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class AutonomousContentService
{
    protected GenerateAiContentService $ai;
    protected const DAILY_LIMIT = 250;

    public function __construct(GenerateAiContentService $ai)
    {
        $this->ai = $ai;
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

    protected function incrementAiUsage(): void
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
    // 1. توليد أسئلة تحدي الشلة (توليد + فلترة صارمة + مدقق حقائق AI منفصل)
    // =========================================================================

    public function generateTriviaQuestions(string $categorySlug, string $difficulty = 'medium', int $count = 8): array
    {
        if (!$this->canMakeAiRequest()) {
            Log::warning('AutonomousContentService: Daily AI quota reached. Skipping trivia generation.');
            return ['generated' => 0, 'approved' => 0, 'rejected' => 0, 'reasons' => ['سقف الاستخدام اليومي ممتلئ']];
        }

        $category = Category::where('slug', $categorySlug)->first();
        if (!$category) {
            $category = Category::where('is_active', true)->first();
            $categorySlug = $category?->slug ?? 'general';
        }

        // المرحلة 1: التوليد المبدئي بـ prompt يشدد على تقارب وتجانس الخيارات وصياغة السؤال الفردي
        $prompt = <<<EOT
أنت خبير محتوى ألعاب ثقافية وجماعية مصرية (تحدي الشلة).
قم بتوليد قائمة من {$count} أسئلة اختيار من متعدد في قسم [{$category->name_ar}] ومستوى صعوبة [{$difficulty}].

شروط صارمة وإلزامية:
1. صياغة السؤال: سؤال واحد فقط ومحدد بوضوح (ممنوع دمج سؤالين، ممنوع الأسئلة الغامضة، ممنوع الأسئلة المتغيرة تاريخياً مثل "من هو الأفضل حالياً").
2. 4 خيارات لكل سؤال:
   - الخيارات الثلاثة الخاطئة (Distractors) يجب أن تكون من **نفس النوع والمستوى تماماً وبنفس الطول والواقعية** (مثلاً: إذا كان السؤال عن مخرج سينمائي مصري، فالخيارات الأربعة كلها مخرجون مصريون كبار؛ إذا كان عن رقم، فالأرقام الأربعة متقاربة؛ إذا كان عن أكلة، فالأربعة أكلات شعبية رئيسية).
   - ممنوع تماماً خيارات مثل: "كل ما سبق"، "لا شيء مما سبق"، أو خيار شاذ يفضح الإجابة الصحيحة.
3. التوزيع العشوائي: موزع correct_index بين 0 و 3 بتوازن.
4. الرد بصيغة JSON فقط كمصفوفة:
[
  {
    "prompt_ar": "نص السؤال هنا؟",
    "options": ["اختيار 1", "اختيار 2", "اختيار 3", "اختيار 4"],
    "correct_index": 0,
    "difficulty": "{$difficulty}",
    "explanation_ar": "توضيح مختصر وممتع للمعلومة"
  }
]
EOT;

        $rawResponse = $this->ai->generateRawContent($prompt, [
            'temperature' => 0.4,
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

        // جلب عينة من أسئلة نفس القسم لفحص التشابه
        $existingPrompts = Question::where('category_id', $category->id)
            ->where('status', 'active')
            ->pluck('normalized_prompt')
            ->filter()
            ->all();

        $batchPrompts = [];

        foreach ($candidates as $item) {
            // أ) التحقق من البنية
            if (!isset($item['prompt_ar'], $item['options'], $item['correct_index'])) {
                $rejectedCount++;
                $rejectionReasons[] = 'بنية السؤال غير مكتملة';
                continue;
            }

            $options = (array) $item['options'];
            $cIndex = (int) $item['correct_index'];
            if (count($options) !== 4 || $cIndex < 0 || $cIndex > 3) {
                $rejectedCount++;
                $rejectionReasons[] = 'عدد الاختيارات ليس 4 أو رقم الإجابة خارج النطاق';
                continue;
            }

            // التحقق من تمايز الخيارات وعدم فراغها
            $uniqueOptions = array_unique(array_map('trim', $options));
            if (count($uniqueOptions) !== 4) {
                $rejectedCount++;
                $rejectionReasons[] = 'الخيارات الأربعة تحتوي على خيارات مكررة';
                continue;
            }

            $promptAr = trim($item['prompt_ar']);
            $normPrompt = ArabicNormalizer::normalize($promptAr);

            // ب) التحقق من أنه سؤال واحد فقط
            if (mb_substr_count($promptAr, '؟') > 1 || mb_substr_count($promptAr, '?') > 1 ||
                str_contains($normPrompt, ' و من هو ') || str_contains($normPrompt, ' و ما هو ')) {
                $rejectedCount++;
                $rejectionReasons[] = 'السؤال مركب ويجمع أكثر من سؤال';
                continue;
            }

            // ج) التحقق من عدم التكرار (بصمة + تشابه Jaccard)
            $pHash = ArabicNormalizer::promptHash($promptAr);
            $correctOpt = $options[$cIndex];
            $aHash = ArabicNormalizer::answerHash($category->slug, $correctOpt);

            // تكرار البصمة بالداتابيز
            if (Question::where('prompt_hash', $pHash)->exists() || Question::where('answer_hash', $aHash)->where('category_id', $category->id)->exists()) {
                $rejectedCount++;
                $rejectionReasons[] = 'السؤال أو الإجابة مكررة في الداتابيز';
                continue;
            }

            // تكرار داخل نفس الدفعة
            if (in_array($normPrompt, $batchPrompts, true)) {
                $rejectedCount++;
                $rejectionReasons[] = 'السؤال مكرر في نفس الدفعة';
                continue;
            }

            // فحص تشابه Jaccard مع الأسئلة الحالية
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

            // د) المرحلة 2: مدقق الحقائق والتجانس المستقل (AI Fact-Checker)
            $verification = $this->verifyQuestionWithAi($promptAr, $options, $correctOpt, $category->name_ar);
            if (!$verification['approved']) {
                $rejectedCount++;
                $rejectionReasons[] = 'رفض المدقق المستقل: ' . ($verification['reason'] ?? 'عدم تطابق معايير الدقة');
                continue;
            }

            // هـ) حساب بصمة المشتتات والاعتماد والنشر
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

    /**
     * المرحلة 2: فحص دقة وحقيقة وتجانس السؤال عبر مدقق AI مستقل
     */
    protected function verifyQuestionWithAi(string $prompt, array $options, string $correctAnswer, string $categoryName): array
    {
        if (!$this->canMakeAiRequest()) {
            return ['approved' => true, 'reason' => 'Skipped AI check due to quota'];
        }

        $optsFormatted = implode("\n", array_map(fn($idx, $opt) => ($idx + 1) . ") " . $opt, array_keys($options), $options));

        $checkPrompt = <<<EOT
أنت مدقق حقائق صارم لألعاب المسابقات الجماعية.
افحص هذا السؤال وخياراته في قسم [{$categoryName}]:

السؤال: {$prompt}
الخيارات:
{$optsFormatted}
الإجابة المعتمدة: {$correctAnswer}

المطلوب التحقق بدقة من 5 معايير:
1. هل الإجابة المعتمدة صحيحة يقيناً كثابت حقيقي؟ (is_factually_correct)
2. هل الخيارات الثلاثة الأخرى خاطئة قطعاً ولا تحتمل أي لبس أو صواب بديل؟ (distractors_definitely_wrong)
3. هل الخيارات الأربعة متجانسة تماماً ومن نفس الفئة المعرفية واللغوية ونفس مستوى التحديد دون خيار شاذ؟ (options_homogeneous)
4. هل السؤال فردي وثابت وليس مركباً ولا غامضاً؟ (single_clear_question)
5. هل المحتوى سليم وخالٍ من الإساءة والسياسة والجدل الحاد؟ (safe_content)

أجب بـ JSON فقط:
{
  "is_factually_correct": true,
  "distractors_definitely_wrong": true,
  "options_homogeneous": true,
  "single_clear_question": true,
  "safe_content": true,
  "verdict": "APPROVE",
  "reason": "OK"
}
لو وجد أي خلل اجعل verdict هو "REJECT" واذكر السبب في reason.
EOT;

        try {
            $raw = $this->ai->generateRawContent($checkPrompt, [
                'temperature' => 0.1,
                'maxOutputTokens' => 500,
            ]);
            $this->incrementAiUsage();

            $data = json_decode($this->cleanJsonString($raw), true);
            if (isset($data['verdict']) && strtoupper($data['verdict']) === 'APPROVE') {
                return ['approved' => true];
            }
            return ['approved' => false, 'reason' => $data['reason'] ?? 'فشل التحقق المعرفي'];
        } catch (\Throwable $e) {
            Log::warning('Verification check exception: ' . $e->getMessage());
            return ['approved' => false, 'reason' => 'استثناء أثناء تدقيق الحقائق'];
        }
    }

    // =========================================================================
    // 2. توليد مجموعات كلمات الجاسوس المتجانسة بدقة (Spy Word Groups)
    // =========================================================================

    public function generateSpyWordGroup(string $packSlug = 'places', string $difficulty = 'medium'): array
    {
        if (!$this->canMakeAiRequest()) {
            return ['success' => false, 'error' => 'سقف الاستخدام اليومي ممتلئ'];
        }

        $existingTitles = SpyWordGroup::where('pack_slug', $packSlug)->pluck('title_ar')->all();
        $existingTitlesStr = implode('، ', array_slice($existingTitles, -10));

        $prompt = <<<EOT
أنت مصمم للعبة "مين الجاسوس" المصرية.
قم بتوليد **مجموعة كلمات مترابطة ومتجانسة بدقة بالغة** (Word Group) في فئة [{$packSlug}] ومستوى صعوبة [{$difficulty}].

شرط جوهري لا يقبل المساومة:
- المجموعة يجب أن تتكون من عنوان واضح ومحدد (مثل: "مدن ساحلية مصرية"، "أكلات فطار شعبي"، "غرف في الشقة"، "معالم سياحية بالقاهرة"، "حلويات شرقية").
- **جميع الكلمات (من 8 إلى 12 كلمة) يجب أن تكون من نفس النوع ونفس مستوى التحديد تماماً**!
- ممنوع منعاً باتاً خلط المستويات (ممنوع وضع غرفة مثل "مطبخ" بجانب مدينة مثل "شرم الشيخ"، وممنوع وضع أثاث مع أماكن).
- تجنب المجموعات الموجودة مسبقاً مثل: [{$existingTitlesStr}].

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
            'pack_slug' => $packSlug,
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
