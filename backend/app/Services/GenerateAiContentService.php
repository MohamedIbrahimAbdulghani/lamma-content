<?php
// Lamma - by Mohamed Ibrahim

namespace App\Services;

use App\Helpers\ArabicTextNormalizer;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GenerateAiContentService
{
    /**
     * توليد محتوى ألعاب بالذكاء الاصطناعي مع منع التكرار والتطبيع
     */
    public function generate(
        string $gameType,
        ?string $category = null,
        int $count = 20,
        array $excludeItems = [],
        ?string $difficulty = null,
        array $categories = []
    ): array
    {
        $apiKey = env('GEMINI_API_KEY');
        $model = env('GEMINI_MODEL', 'gemini-2.0-flash');

        if (empty($apiKey)) {
            Log::warning('GEMINI_API_KEY غير معين في ملف .env');
            return [];
        }

        // تجهيز قائمة المستبعدات بعد التطبيع
        $normalizedExcludes = [];
        foreach ($excludeItems as $item) {
            if (!empty($item)) {
                $normalizedExcludes[ArabicTextNormalizer::normalize($item)] = true;
            }
        }

        // بناء الـ prompt حسب نوع اللعبة والإعدادات
        $prompt = $this->buildPrompt(
            gameType: $gameType,
            category: $category,
            count: $count,
            recentExcludes: array_slice($excludeItems, 0, 50),
            difficulty: $difficulty,
            categories: $categories
        );

        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";

        $body = [
            'contents' => [
                [
                    'role' => 'user',
                    'parts' => [
                        ['text' => $prompt],
                    ],
                ],
            ],
            'generationConfig' => [
                'temperature' => 0.5,
                'responseMimeType' => 'application/json',
            ],
        ];

        try {
            $response = Http::timeout(30)->post($url, $body);

            if (!$response->successful()) {
                Log::error('فشل استدعاء Gemini API: ' . $response->status() . ' - ' . $response->body());
                return [];
            }

            $data = $response->json();
            $rawText = $data['candidates'][0]['content']['parts'][0]['text'] ?? '';

            if (empty($rawText)) {
                return [];
            }

            $cleanJson = preg_replace('/^```(?:json)?\s*/i', '', trim($rawText));
            $cleanJson = preg_replace('/\s*```$/', '', $cleanJson);

            $decoded = json_decode($cleanJson, true);
            $items = is_array($decoded) ? (isset($decoded['items']) ? $decoded['items'] : $decoded) : [];

            // تصفية المحتوى والتحقق الصارم من صحة الأسئلة ومنع التكرار
            $filtered = [];
            $seenInBatch = [];

            foreach ($items as $item) {
                if (!is_array($item)) {
                    continue;
                }

                $keyText = $this->extractKeyText($gameType, $item);
                if (empty($keyText)) {
                    continue;
                }

                // التحقق من بنية سؤال التحدي
                if ($gameType === 'trivia') {
                    $options = $item['options'] ?? [];
                    if (!is_array($options) || count($options) !== 4) {
                        continue;
                    }
                    // التأكد أن الاختيارات الـ 4 فريدة وغير فارغة
                    $trimmedOptions = array_map('trim', $options);
                    if (count(array_unique($trimmedOptions)) !== 4 || in_array('', $trimmedOptions, true)) {
                        continue;
                    }
                    $correctIndex = $item['correct_index'] ?? null;
                    if (!is_int($correctIndex) || $correctIndex < 0 || $correctIndex > 3) {
                        continue;
                    }
                    // مطابقة الصعوبة إذا كانت محددة
                    if (!empty($difficulty) && $difficulty !== 'all') {
                        $itemDiff = $item['difficulty'] ?? 'medium';
                        if ($itemDiff !== $difficulty) {
                            $item['difficulty'] = $difficulty;
                        }
                    }
                }

                $norm = ArabicTextNormalizer::normalize($keyText);
                if (isset($normalizedExcludes[$norm]) || isset($seenInBatch[$norm])) {
                    continue;
                }

                $seenInBatch[$norm] = true;
                $filtered[] = $item;

                if (count($filtered) >= $count) {
                    break;
                }
            }

            return $filtered;

        } catch (\Throwable $e) {
            Log::error('استثناء أثناء توليد المحتوى بـ Gemini: ' . $e->getMessage());
            return [];
        }
    }

    private function extractKeyText(string $gameType, array $item): string
    {
        if ($gameType === 'trivia') {
            return $item['prompt_ar'] ?? '';
        }
        return $item['word_ar'] ?? ($item['prompt_ar'] ?? '');
    }

    private function buildPrompt(
        string $gameType,
        ?string $category,
        int $count,
        array $recentExcludes,
        ?string $difficulty = null,
        array $categories = []
    ): string
    {
        $excludeText = '';
        if (!empty($recentExcludes)) {
            $excludeList = implode('، ', array_map(fn($e) => "\"$e\"", $recentExcludes));
            $excludeText = "\nممنوع منعاً باتاً تكرار أو اقتراح أي عنصر من هذه القائمة التي لُعبت بالفعل مؤخراً:\n[$excludeList]\n";
        }

        switch ($gameType) {
            case 'spy':
                $catAr = match ($category) {
                    'movies' => 'أفلام ومسلسلات مصرية شهيرة',
                    'food' => 'أكلات مصرية شعبية ومشهورة',
                    default => 'أماكن ومعالم وشوارع مصرية معروفة (القاهرة، الإسكندرية، محافظات مصر)',
                };
                return "أنت خبير محتوى ألعاب جماعية مصرية لتطبيق 'لمّة' ولعبة 'مين الجاسوس'.
المطلوب: توليد $count مكان أو كلمة مصرية لتصنيف '$catAr'.
شروط صارمة:
1. أسماء مصرية مشهورة يعرفها الجمهور العام بسهولة (أماكن عامة، معالم، أكلات، أفلام).
2. لا تستخدم أماكن غير حقيقية أو غامضة جداً.
$excludeText
أرجع JSON array فقط من الكائنات بهذا الشكل:
[
  {
    \"word_ar\": \"خان الخليلي\",
    \"category\": \"أماكن\",
    \"hint\": \"مكان تاريخي وسياحي شهير\"
  }
]";

            case 'trivia':
                // تجهيز قائمة الأقسام المسموحة
                $activeCategories = !empty($categories) ? $categories : ($category ? [$category] : []);
                $catNamesMap = [
                    'movies' => 'أفلام ومسلسلات مصرية',
                    'sports' => 'كورة ورياضة مصرية',
                    'afeehat' => 'إفيهات وقفشات سينمائية ومسرحية',
                    'history' => 'تاريخ وجغرافيا ومعالم مصر',
                    'general' => 'معلومات عامة وثقافة مصرية',
                ];

                if (!empty($activeCategories)) {
                    $selectedNames = [];
                    foreach ($activeCategories as $c) {
                        if (isset($catNamesMap[$c])) {
                            $selectedNames[] = $catNamesMap[$c];
                        }
                    }
                    $catsClause = "الأقسام المسموحة حصراً: [" . implode('، ', $selectedNames) . "]. لا تخرج إطلاقاً عن هذه الأقسام وتوزع الأسئلة بينها بتوازن.";
                } else {
                    $catsClause = "الأسئلة متنوعة ومتوازنة من كل الأقسام: أفلام ومسلسلات، كورة مصرية، إفيهات وقفشات، تاريخ وجغرافيا، عامة.";
                }

                $diffClause = match ($difficulty) {
                    'easy' => 'مستوى الصعوبة: سهل (أسئلة يعرفها أغلب الجمهور بسهولة).',
                    'medium' => 'مستوى الصعوبة: متوسط (تتطلب تركيزاً ومعرفة متوسطة).',
                    'hard' => 'مستوى الصعوبة: حراق / صعب (تتطلب دقة وتفاصيل دقيقة).',
                    default => 'مستوى الصعوبة: متنوع ومتوازن بين السهل والمتوسط والصعب.',
                };

                return "أنت صانع أسئلة مسابقات مصري محترف لتطبيق 'لمّة' ولعبة 'تحدي الشلة'.
المطلوب: توليد $count سؤال اختيار من متعدد باللهجة المصرية الدارجة الممتعة والمناسبة لجمهور العائلة والأصحاب.
$catsClause
$diffClause
شروط أمان ومحتوى صارمة:
1. معلومات موثقة وصحيحة 100% بدون هلوسة أو تأليف، وبدون أي غموض في السؤال.
2. 4 اختيارات بالضبط مختلفة وفريدة ولا تحتوي اختيارات مكررة أو فارغة، مع تحديد correct_index بدقة (من 0 إلى 3).
3. استبعاد تام لأي موضوعات دينية جدلية أو سياسية أو محتوى مسيء أو خادش.
4. تحديد اسم القسم (category_slug) بوضوح ومستوى الصعوبة (difficulty).
$excludeText
أرجع JSON array فقط بدون أي نصوص تمهيدية أو Markdown خارجي:
[
  {
    \"type\": \"mcq\",
    \"prompt_ar\": \"مين صاحب إفيه: يا صفيحة زبالة منورة؟\",
    \"options\": [\"عادل إمام\", \"محمد هنيدي\", \"أحمد حلمي\", \"نجيب الريحاني\"],
    \"correct_index\": 1,
    \"category_slug\": \"afeehat\",
    \"difficulty\": \"medium\",
    \"explanation_ar\": \"محمد هنيدي في فيلم صعيدي في الجامعة الأمريكية\"
  }
]";

            case 'charades':
            default:
                $catAr = match ($category) {
                    'jobs' => 'مهن وحرف وشخصيات مصرية مميزة',
                    'actions' => 'أفعال ومواقف وتعبيرات يومية مصرية مضحكة',
                    default => 'أفلام ومسرحيات ومسلسلات مصرية شهيرة جداً',
                };
                return "أنت خبير ألعاب تمثيل بدون كلام (تمثيل صامت / مثّل ومتتكلمش) لتطبيق 'لمّة'.
المطلوب: توليد $count عنوان أو كلمة قابلة للتمثيل بسهولة من تصنيف '$catAr'.
شروط صارمة:
1. كلمات وأعمال مصرية شهيرة جداً وسهلة أو متوسطة في التخمين بالتمثيل الصامت.
2. مناسبة للجميع وتثير الضحك والمنافسة.
$excludeText
أرجع JSON array فقط:
[
  {
    \"word_ar\": \"الناظر\",
    \"category\": \"أفلام\",
    \"difficulty\": \"easy\"
  }
]";
        }
    }
}

