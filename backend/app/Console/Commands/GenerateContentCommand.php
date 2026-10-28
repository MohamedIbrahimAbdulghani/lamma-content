<?php
// Lamma - by Mohamed Ibrahim

namespace App\Console\Commands;

use App\Models\Category;
use App\Models\Question;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GenerateContentCommand extends Command
{
    protected $signature = 'content:generate 
                            {--category= : تصنيف معين لتوليد أسئلة له} 
                            {--count=20 : عدد العناصر المطلوب توليدها} 
                            {--no-search : تعطيل أداة البحث في جوجل (مفعلة افتراضياً)}';

    protected $description = 'توليد أسئلة ومحتوى مصري جديد باستخدام Gemini API كمسودات معلقة (Pending)';

    public function handle(): int
    {
        $apiKey = env('GEMINI_API_KEY');
        $model = env('GEMINI_MODEL', 'gemini-2.0-flash');

        if (empty($apiKey)) {
            $this->warn('مفتاح GEMINI_API_KEY غير موجود في ملف .env. يمكنك إضافة المفتاح لاحقاً لتوليد أسئلة بالذكاء الاصطناعي.');
            return 0;
        }

        $categorySlug = $this->option('category');
        $count = (int) $this->option('count');
        if ($count <= 0) {
            $count = 20;
        }

        $noSearchOption = (bool) $this->option('no-search');
        $enableSearch = !$noSearchOption;

        $this->info("بدء توليد {$count} سؤال/محتوى عبر نموذج {$model}...");
        if ($enableSearch) {
            $this->line("أداة Google Search مفعلة افتراضياً للتحقق من الحقائق.");
        } else {
            $this->line("تم تفعيل خيار --no-search (البحث في جوجل معطل).");
        }

        $categoriesQuery = Category::where('kind', 'trivia');
        if ($categorySlug) {
            $categoriesQuery->where('slug', $categorySlug);
        }
        $categories = $categoriesQuery->get();

        if ($categories->isEmpty()) {
            $this->error("التصنيف المطلوب غير موجود.");
            return 1;
        }

        $insertedCount = 0;
        $totalCats = $categories->count();

        foreach ($categories as $index => $category) {
            $this->line("جاري توليد محتوى لتصنيف: {$category->name_ar} ({$category->slug})...");

            $items = $this->callGemini($apiKey, $model, $category, min($count, 20), $enableSearch);

            if (empty($items)) {
                $this->warn("لم يتم استلام أسئلة صالحة لتصنيف {$category->name_ar}.");
            } else {
                $catInserted = 0;
                foreach ($items as $item) {
                    if ($this->validateAndInsertQuestion($category, $item)) {
                        $catInserted++;
                    }
                }
                $insertedCount += $catInserted;
                $this->info("تم إدخال {$catInserted} سؤال كمسودة معلقة (Pending) لتصنيف {$category->name_ar}.");
            }

            // انتظار 20 ثانية بين التصنيفات إذا كان هناك أكثر من تصنيف
            if ($index < $totalCats - 1) {
                $this->line("انتظار 20 ثانية قبل الانتقال للتصنيف التالي لتجنب حدود الاستخدام (Rate limit)...");
                sleep(20);
            }
        }

        $this->newLine();
        if ($insertedCount > 0) {
            $this->info("تم بنجاح إدخال {$insertedCount} سؤال جديد بحالة معلقة (is_active = 0).");
            $this->comment("المحتوى لم يُنشر بعد في اللعبة حتى تراجعه.");
            $this->line("لمراجعة الأسئلة وتفعيلها أو حذفها، شغل الأمر التالي:");
            $this->info("  php artisan content:review");
        } else {
            $this->info('لم يتم إدخال أسئلة جديدة (ربما كلها مكررة أو حدث خطأ في التنسيق).');
        }

        return 0;
    }

    private function callGemini(string $apiKey, string $model, Category $category, int $count, bool $enableSearch): array
    {
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";

        $systemPrompt = "أنت صانع محتوى خبير للألعاب الجماعية المصرية وتحديداً تطبيق 'لمّة'.
مهمتك توليد أسئلة مسابقات دقيقة وصحيحة 100% باللهجة المصرية الدارجة لتصنيف '{$category->name_ar}' ({$category->slug}).

قواعد صارمة جداً لمنع التأليف أو الهلوسة:
1. توليد أسئلة عن حقائق ووقائع أنت واثق منها بنسبة 100% فقط (High Confidence Facts).
2. ممنوع منعاً باتاً تأليف أي إيفيه، أو جملة، أو اسم فيلم، أو مشهد غير حقيقي في الواقع (No invented quotes or scenes).
3. في تصنيفات الأفيهات (afeehat)، ومين اللي قال (who_said)، وتخمين الفيلم (guess_movie): يجب ذكر اسم الفيلم أو المسرحية أو المسلسل الحقيقي بدقة في نص السؤال أو في الشرح.
4. إذا لم تكن متأكداً تماماً من الاقتباس أو المعلومة، تخطّها فوراً ولا تولدها. الأفضل توليد عدد أقل ولكن صحيح 100%.
5. الخيارات الأربعة يجب أن تكون خيارات منطقية من أفلام أو شخصيات مصرية حقيقية، مع إجابة صحيحة واحدة فقط.

أنواع الأسئلة المتاحة:
- mcq: سؤال اختيار من متعدد (4 خيارات حقيقية).
- emoji_movie: لغز إيموجي لفيلم مصري حقيقي مشهور (emoji_prompt يحتوي على الإيموجيز و options 4 أسماء أفلام حقيقية).
- true_false: معلومة حقيقية صح أو غلط (options عبارة عن ['صح', 'غلط'] فقط).
- complete_phrase: أكمل الإيفيه أو الجملة الشهيرة الحقيقية (مع ذكر العمل، 4 خيارات).
- who_said: مين صاحب الجملة أو الإيفيه الشهير في العمل المحدد (4 خيارات لأسماء شخصيات أو ممثلين حقيقيين).

يجب أن ترجع النتيجة كـ JSON Array فقط من الكائنات بدون أي markdown خارجي إضافي أو شروحات.
شكل كل عنصر:
{
  \"type\": \"mcq|emoji_movie|true_false|complete_phrase|who_said\",
  \"prompt_ar\": \"نص السؤال مع ذكر العمل الفني بدقة\",
  \"emoji_prompt\": \"🎬🍿 (إن وجد أو null)\",
  \"options\": [\"خيار 1\", \"خيار 2\", \"خيار 3\", \"خيار 4\"],
  \"correct_index\": 0,
  \"difficulty\": \"easy|medium|hard\",
  \"explanation_ar\": \"شرح صحيح وموثق للإجابة مع اسم الشخصية والعمل الفني\"
}";

        $fullPrompt = "{$systemPrompt}\n\nالمطلوب الآن: أنتج لي {$count} سؤال دقيق وموثق 100% لتصنيف '{$category->name_ar}' بتنسيق JSON array الصارم فقط.";

        $body = [
            'contents' => [
                [
                    'role' => 'user',
                    'parts' => [
                        ['text' => $fullPrompt]
                    ]
                ]
            ],
            'generationConfig' => [
                'temperature' => 0.4,
                'responseMimeType' => 'application/json',
            ]
        ];

        if ($enableSearch) {
            $body['tools'] = [
                [
                    'googleSearch' => (object)[]
                ]
            ];
        }

        $maxRetries = 3;
        for ($attempt = 1; $attempt <= $maxRetries; $attempt++) {
            try {
                $response = Http::timeout(60)->post($url, $body);
                $status = $response->status();

                if ($response->successful()) {
                    $responseData = $response->json();
                    $text = $responseData['candidates'][0]['content']['parts'][0]['text'] ?? null;

                    if (empty($text)) {
                        $this->warn("الاستجابة من Gemini فارغة.");
                        return [];
                    }

                    $cleanJson = preg_replace('/^```(?:json)?\s*/i', '', trim($text));
                    $cleanJson = preg_replace('/\s*```$/', '', $cleanJson);

                    $decoded = json_decode($cleanJson, true);
                    if (is_array($decoded)) {
                        return isset($decoded['questions']) ? $decoded['questions'] : $decoded;
                    }

                    $this->warn("تعذر فك ترميز JSON من الاستجابة.");
                    return [];
                }

                $rawError = $response->json('error.message') ?? $response->body();
                $cleanMessage = str_replace($apiKey, '***', (string) $rawError);

                if ($status === 429) {
                    // إذا كان البحث مفعلاً ورجع خطأ 429 يخص الكوتة (Quota)
                    if ($enableSearch && (stripos($cleanMessage, 'quota') !== false || stripos($cleanMessage, 'limit') !== false)) {
                        $this->warn("تم استنفاد كوتة أداة البحث في جوجل (Google Search quota is exhausted). جاري إعادة المحاولة بدون أداة البحث فوراً لمرة واحدة...");
                        return $this->callGemini($apiKey, $model, $category, $count, false);
                    }

                    $this->warn("تم الوصول لحدود استخدام Gemini (Rate limit 429). انتظر قليلاً للمحاولة {$attempt}/{$maxRetries}.. الرسالة: {$cleanMessage}");
                    sleep(10 * $attempt);
                    continue;
                }

                if ($status === 503) {
                    $this->warn("النموذج مشغول حالياً (Model busy 503). جاري إعادة المحاولة {$attempt}/{$maxRetries}.. الرسالة: {$cleanMessage}");
                    sleep(5 * $attempt);
                    continue;
                }

                $this->error("HTTP {$status}: {$cleanMessage}");
                return [];

            } catch (\Exception $e) {
                $cleanExMessage = str_replace($apiKey, '***', $e->getMessage());
                Log::error('Gemini call exception: ' . $cleanExMessage);
                if ($attempt === $maxRetries) {
                    $this->error("خطأ استثناء أثناء الاتصال بـ Gemini: {$cleanExMessage}");
                    return [];
                }
                sleep(3);
            }
        }

        return [];
    }

    private function validateAndInsertQuestion(Category $category, array $item): bool
    {
        if (empty($item['prompt_ar']) || !isset($item['options']) || !isset($item['correct_index'])) {
            return false;
        }

        $type = $item['type'] ?? 'mcq';
        $allowedTypes = ['mcq', 'emoji_movie', 'true_false', 'complete_phrase', 'who_said'];
        if (!in_array($type, $allowedTypes)) {
            $type = 'mcq';
        }

        $options = (array) $item['options'];
        if ($type === 'true_false' && count($options) !== 2) {
            $options = ['صح', 'غلط'];
        } elseif ($type !== 'true_false' && count($options) !== 4) {
            return false;
        }

        $correctIndex = (int) $item['correct_index'];
        if ($correctIndex < 0 || $correctIndex >= count($options)) {
            return false;
        }

        $difficulty = $item['difficulty'] ?? 'medium';
        if (!in_array($difficulty, ['easy', 'medium', 'hard'])) {
            $difficulty = 'medium';
        }

        $hash = Question::makeContentHash($item['prompt_ar']);
        if (Question::where('content_hash', $hash)->exists()) {
            return false;
        }

        // إدخال السؤال بحالة is_active = false (pending) حتى تتم مراجعته
        Question::create([
            'category_id' => $category->id,
            'type' => $type,
            'prompt_ar' => trim($item['prompt_ar']),
            'emoji_prompt' => !empty($item['emoji_prompt']) ? trim($item['emoji_prompt']) : null,
            'options' => array_values($options),
            'correct_index' => $correctIndex,
            'difficulty' => $difficulty,
            'explanation_ar' => !empty($item['explanation_ar']) ? trim($item['explanation_ar']) : null,
            'source' => 'gemini',
            'content_hash' => $hash,
            'is_active' => false,
            'published_at' => now(),
        ]);

        return true;
    }
}
