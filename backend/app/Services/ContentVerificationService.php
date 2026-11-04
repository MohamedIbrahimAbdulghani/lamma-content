<?php
// Lamma - by Mohamed Ibrahim

namespace App\Services;

use App\Helpers\ArabicNormalizer;
use App\Models\Category;
use Illuminate\Support\Facades\Log;

class ContentVerificationService
{
    protected GenerateAiContentService $ai;

    /**
     * الكلمات والأنماط الممنوعة التي تشير إلى أرقام أو إحصائيات متغيرة أو زمنية
     */
    protected const FORBIDDEN_DYNAMIC_PATTERNS = [
        '/حالياً/u',
        '/في الوقت الحالي/u',
        '/الآن/u',
        '/أحدث/u',
        '/الأحدث/u',
        '/أكبر عدد أهداف حالي/u',
        '/الهداف التاريخي/u',
        '/أغلى صفقة حالية/u',
        '/أعلى سعر حالي/u',
        '/الأكثر تتويجاً حالياً/u',
        '/المدرب الحالي/u',
        '/الرئيس الحالي/u',
    ];

    /**
     * تعريفات دقيقة لحدود الأقسام وما يدخل فيها وما لا يدخل
     */
    public const CATEGORY_DEFINITIONS = [
        'movies' => [
            'name_ar' => 'أفلام ومسلسلات',
            'scope' => 'الأعمال السينمائية، الأفلام المصرية، المسلسلات التلفزيونية، المخرجين، الممثلين، وتواريخ عرض الأعمال الفنية فقط.',
            'not_allowed' => 'ممنوع إقحام مواضيع كرة القدم أو الأندية أو الرياضة أو الأحداث التاريخية العامة حتى لو وُجد فيلم عنها؛ يجب أن يكون موضوع السؤال عملاً سينمائياً أو تلفزيونياً خالصاً.',
        ],
        'sports' => [
            'name_ar' => 'كورة مصرية',
            'scope' => 'كرة القدم المصرية والعربية، بطولات الأندية (الأهلي، الزمالك، الإسماعيلي، إلخ)، منتخب مصر، بطولات كأس أمم إفريقيا، واللاعبين والمدربين الرياضيين.',
            'not_allowed' => 'ممنوع إقحام الأعمال السينمائية أو الإفيهات الفنية؛ السؤال رياضي خالص عن بطولات ومباريات وأندية ولاعبين.',
        ],
        'afeehat' => [
            'name_ar' => 'إفيهات وقفشات',
            'scope' => 'الجمل الكوميدية الشهيرة (الإفيهات)، القفشات المسرحية والسينمائية المصرية الراسخة، ومن قائل الإفيه أو في أي فيلم/مسرحية قيل.',
            'not_allowed' => 'ممنوع تحويل السؤال إلى مجرد معلومة تاريخية جافة أو سؤال كروي؛ يجب أن يتمحور حول إفيه كوميدي معروف للجمهور.',
        ],
        'history' => [
            'name_ar' => 'تاريخ وجغرافيا',
            'scope' => 'تاريخ مصر القديم والمعاصر، المعالم التاريخية الراسخة (الأهرامات، القلاع، المساجد، الكنائس، السدود، القنوات)، محافظات ومدن وجغرافيا مصر الثابتة.',
            'not_allowed' => 'ممنوع الأرقام الاقتصادية الحديثة المتغيرة أو الأسئلة الفنية أو الكروية.',
        ],
        'general' => [
            'name_ar' => 'معلومات عامة',
            'scope' => 'حقائق عامة وثابتة علمية وثقافية وجغرافية مصرية وعالمية معروفة ومسلم بها.',
            'not_allowed' => 'ممنوع أي سؤال يحمل وجهاً سياسياً أو جدلاً عقائدياً أو معلومة متغيرة أو شائعة.',
        ],
    ];

    public function __construct(GenerateAiContentService $ai)
    {
        $this->ai = $ai;
    }

    public function getCanonicalSlug(string $slug): string
    {
        return Category::canonicalSlug($slug);
    }

    public function verifyQuestion(array $item, string $categorySlug = 'general'): array
    {
        $res = $this->verifyTriviaQuestion(
            $item['prompt_ar'] ?? '',
            $item['options'] ?? [],
            $item['correct_index'] ?? 0,
            $categorySlug,
            $item['difficulty'] ?? 'medium'
        );

        return [
            'valid' => $res['approved'],
            'approved' => $res['approved'],
            'reason' => $res['reason'] ?? '',
            'blind_answer' => $res['blind_answer'] ?? null,
            'blind_confidence' => $res['blind_confidence'] ?? null,
        ];
    }

    /**
     * تدقيق شامل للسؤال عبر 3 مراحل متتالية:
     * 1. الفحوصات الآلية البرمجية الصارمة (Deterministic Checks).
     * 2. التحقق الأعمى المستقل (Blind Verification) بدون إعطاء الإجابة للـ AI.
     * 3. مدقق المراجعة المستقل ومصنف الأقسام (Reviewer Fact-Checker & Category Classifier).
     *
     * @return array{approved: bool, reason: string|null, blind_answer: string|null, blind_confidence: int|null}
     */
    public function verifyTriviaQuestion(
        string $prompt,
        array $options,
        int $correctIndex,
        string $categorySlug,
        string $difficulty = 'medium'
    ): array {
        // =====================================================================
        // المرحلة 1: الفحوصات الآلية البرمجية (Deterministic Checks)
        // =====================================================================
        $autoCheck = $this->runAutomatedChecks($prompt, $options, $correctIndex);
        if (!$autoCheck['passed']) {
            return [
                'approved' => false,
                'stage' => 'automated_checks',
                'reason' => $autoCheck['reason'],
                'blind_answer' => null,
                'blind_confidence' => null,
            ];
        }

        $correctAnswer = trim($options[$correctIndex]);
        $catSlug = Category::canonicalSlug($categorySlug);
        $catDef = self::CATEGORY_DEFINITIONS[$catSlug] ?? self::CATEGORY_DEFINITIONS['general'];

        // =====================================================================
        // المرحلة 2: التحقق الأعمى المستقل (Blind Verification)
        // نرسل السؤال والخيارات فقط دون ذكر الإجابة الصحيحة أو رقمها إطلاقاً
        // =====================================================================
        $shuffledOptions = $options;
        shuffle($shuffledOptions); // خلط عشوائي لمنع أي انحياز ترتيبي

        $optsText = '';
        foreach ($shuffledOptions as $i => $opt) {
            $letter = chr(65 + $i); // A, B, C, D
            $optsText .= "({$letter}) {$opt}\n";
        }

        $blindPrompt = <<<EOT
أنت حكم وخبير مسابقات معرفية صارم ومحايد.
أجب عن هذا السؤال بدقة بالغة باختيار إجابة واحدة صحيحة حصراً من بين الخيارات الأربعة:

السؤال: {$prompt}
الخيارات:
{$optsText}

شروط إلزامية:
1. اختر بدقة الخيار الصحيح الوحيد علمياً وتاريخياً.
2. إذا كان السؤال غامضاً أو يحتمل أكثر من إجابة صحيحة أو لا توجد إجابة صحيحة، أو كان مبنياً على معلومة غير مؤكدة، اذكر ذلك في has_ambiguity واجعل confidence منخفضة.
3. حدد مستوى ثقتك من 0 إلى 100%.

أجب بصيغة JSON فقط:
{
  "selected_option": "النص المطابق تماماً للخيار المختار",
  "confidence": 95,
  "has_ambiguity": false,
  "has_multiple_correct": false,
  "brief_reason": "سبب الاختيار باختصار شديد"
}
EOT;

        try {
            $rawBlind = $this->ai->generateRawContent($blindPrompt, [
                'temperature' => 0.0,
                'maxOutputTokens' => 300,
            ]);

            $blindData = json_decode($this->cleanJson($rawBlind), true);
            if (!is_array($blindData) || !isset($blindData['selected_option'])) {
                return [
                    'approved' => false,
                    'stage' => 'blind_verification',
                    'reason' => 'فشل استلام رد التحقق الأعمى من الذكاء الاصطناعي',
                    'blind_answer' => null,
                    'blind_confidence' => null,
                ];
            }

            $selectedOption = trim((string) $blindData['selected_option']);
            $confidence = (int) ($blindData['confidence'] ?? 0);
            $hasAmbiguity = (bool) ($blindData['has_ambiguity'] ?? false);
            $hasMultiple = (bool) ($blindData['has_multiple_correct'] ?? false);

            $cleanSelected = trim($selectedOption);
            if (preg_match('/^\(?([A-D])\)?$/i', $cleanSelected, $m)) {
                $letterIndex = ord(strtoupper($m[1])) - 65;
                if (isset($shuffledOptions[$letterIndex])) {
                    $cleanSelected = trim($shuffledOptions[$letterIndex]);
                }
            } else {
                $cleanSelected = preg_replace('/^\s*\(?[A-Da-d1-4]\)?[\s\.\:\-–—\)]+/u', '', $cleanSelected);
                $cleanSelected = trim($cleanSelected);
            }

            // مطابقة الإجابة المنتخبة مع الإجابة المعلنة بالتطبيع العربي
            $normSelected = ArabicNormalizer::normalize($cleanSelected);
            $normCorrect = ArabicNormalizer::normalize($correctAnswer);

            if ($normSelected !== $normCorrect) {
                return [
                    'approved' => false,
                    'stage' => 'blind_verification',
                    'reason' => "فشل التحقق الأعمى: الموديل اختار ({$selectedOption}) بينما الإجابة المعلنة ({$correctAnswer})",
                    'blind_answer' => $selectedOption,
                    'blind_confidence' => $confidence,
                ];
            }

            if ($confidence < 90) {
                return [
                    'approved' => false,
                    'stage' => 'blind_verification',
                    'reason' => "ثقة التحقق الأعمى منخفضة ({$confidence}% أقل من العتبة المطلوبة 90%)",
                    'blind_answer' => $selectedOption,
                    'blind_confidence' => $confidence,
                ];
            }

            if ($hasAmbiguity || $hasMultiple) {
                return [
                    'approved' => false,
                    'stage' => 'blind_verification',
                    'reason' => 'السؤال غامض أو يحتمل أكثر من إجابة صحيحة في التحقق الأعمى',
                    'blind_answer' => $selectedOption,
                    'blind_confidence' => $confidence,
                ];
            }
        } catch (\Throwable $e) {
            Log::warning('Blind verification exception: ' . $e->getMessage());
            return [
                'approved' => false,
                'stage' => 'blind_verification',
                'reason' => 'تعذر إتمام التحقق الأعمى (مهلة أو خطأ اتصال)',
                'blind_answer' => null,
                'blind_confidence' => null,
            ];
        }

        // =====================================================================
        // المرحلة 3: مدقق المراجعة المستقل ومصنف الأقسام (Reviewer & Classifier)
        // =====================================================================
        $distractors = [];
        foreach ($options as $idx => $opt) {
            if ($idx !== $correctIndex) {
                $distractors[] = $opt;
            }
        }
        $distractorsList = implode(' | ', $distractors);

        $reviewerPrompt = <<<EOT
أنت رئيس لجنة تدقيق المحتوى وتصنيف الأقسام لمسابقات المعرفة المصرية.
افحص هذا السؤال وإجابته بدقة صارمة:

السؤال: {$prompt}
الإجابة الصحيحة المعلنة: {$correctAnswer}
الخيارات الثلاثة الأخرى (المشتتات): [{$distractorsList}]
القسم المطلوب التحقق من الانتماء الحصري له: [{$catDef['name_ar']}]
نطاق هذا القسم: {$catDef['scope']}
الممنوع في هذا القسم: {$catDef['not_allowed']}

أجب بنعم (true) أو لا (false) على المعايير الخمسة القطعية التالية بصيغة JSON فقط:
{
  "is_answer_factually_indisputable": true,
  "are_all_distractors_definitely_false": true,
  "is_single_unambiguous_question": true,
  "is_strictly_within_category": true,
  "no_mutable_or_temporal_facts": true,
  "verdict": "APPROVE",
  "reason": "توضيح مختصر"
}

قاعدة صارمة: إذا كانت أي إجابة من المعايير الخمسة false، اجعل verdict = "REJECT" واذكر السبب.
EOT;

        try {
            $rawReviewer = $this->ai->generateRawContent($reviewerPrompt, [
                'temperature' => 0.0,
                'maxOutputTokens' => 350,
            ]);

            $reviewData = json_decode($this->cleanJson($rawReviewer), true);
            if (!is_array($reviewData) || !isset($reviewData['verdict'])) {
                return [
                    'approved' => false,
                    'stage' => 'reviewer_verification',
                    'reason' => 'فشل استلام رد مدقق المراجعة من الذكاء الاصطناعي',
                    'blind_answer' => $correctAnswer,
                    'blind_confidence' => 100,
                ];
            }

            $verdict = strtoupper((string) $reviewData['verdict']);
            $isFactual = (bool) ($reviewData['is_answer_factually_indisputable'] ?? false);
            $distractorsFalse = (bool) ($reviewData['are_all_distractors_definitely_false'] ?? false);
            $singleQuestion = (bool) ($reviewData['is_single_unambiguous_question'] ?? false);
            $strictlyInCat = (bool) ($reviewData['is_strictly_within_category'] ?? false);
            $noMutable = (bool) ($reviewData['no_mutable_or_temporal_facts'] ?? false);

            if ($verdict !== 'APPROVE' || !$isFactual || !$distractorsFalse || !$singleQuestion || !$strictlyInCat || !$noMutable) {
                $reason = $reviewData['reason'] ?? 'فشل اجتياز معايير لجنة المراجعة وتصنيف الأقسام';
                return [
                    'approved' => false,
                    'stage' => 'reviewer_verification',
                    'reason' => $reason,
                    'blind_answer' => $correctAnswer,
                    'blind_confidence' => 100,
                ];
            }

            return [
                'approved' => true,
                'stage' => 'all_passed',
                'reason' => 'اجتاز التحقق الأعمى، التدقيق المعرفي، وتصنيف القسم بنجاح تام',
                'blind_answer' => $correctAnswer,
                'blind_confidence' => 100,
            ];
        } catch (\Throwable $e) {
            Log::warning('Reviewer verification exception: ' . $e->getMessage());
            return [
                'approved' => false,
                'stage' => 'reviewer_verification',
                'reason' => 'تعذر إتمام مرحلة المراجعة (مهلة أو خطأ اتصال)',
                'blind_answer' => $correctAnswer,
                'blind_confidence' => 100,
            ];
        }
    }

    /**
     * فحص انتماء كلمة/عنصر لقسمه الصارم (للجاسوس والتمثيل)
     */
    public function verifyItemCategory(string $gameType, string $itemText, string $categorySlug): array
    {
        $canonical = Category::canonicalSlug($categorySlug);
        $prompt = match ($gameType) {
            'spy' => "هل المكان أو الكلمة '{$itemText}' تنتمي حصراً ومباشرة إلى حزمة '{$canonical}' في ألعاب التخمين؟ أجب بـ JSON: {\"belongs\": true/false, \"reason\": \"...\"}",
            'charades' => "هل العمل أو الكلمة '{$itemText}' قابلة للتمثيل الحركي وتنتمي حصراً لقسم '{$canonical}'؟ أجب بـ JSON: {\"belongs\": true/false, \"reason\": \"...\"}",
            default => "هل ينتمي '{$itemText}' للقسم '{$canonical}'؟ أجب بـ JSON: {\"belongs\": true/false, \"reason\": \"...\"}",
        };

        try {
            $raw = $this->ai->generateRawContent($prompt, ['temperature' => 0.0, 'maxOutputTokens' => 200]);
            $data = json_decode($this->cleanJson($raw), true);
            $belongs = (bool) ($data['belongs'] ?? false);
            return [
                'approved' => $belongs,
                'reason' => $data['reason'] ?? ($belongs ? 'مطابق' : 'غير مطابق للقسم'),
            ];
        } catch (\Throwable $e) {
            return ['approved' => false, 'reason' => 'فشل الاتصال بالمدقق الفئوي'];
        }
    }

    /**
     * الفحوصات الآلية البرمجية الصارمة (Deterministic Checks)
     */
    public function runAutomatedChecks(string $prompt, array $options, int $correctIndex): array
    {
        $prompt = trim($prompt);

        // 1. طول السؤال الأدنى
        if (mb_strlen($prompt) < 8) {
            return ['passed' => false, 'reason' => 'نص السؤال قصير جداً'];
        }

        // 2. فحص عدد الخيارات (4 خيارات بالضبط)
        if (count($options) !== 4) {
            return ['passed' => false, 'reason' => 'عدد الخيارات ليس 4 بالضبط (يوجد ' . count($options) . ' خيارات)'];
        }

        // 3. صحة فهرس الإجابة
        if ($correctIndex < 0 || $correctIndex > 3) {
            return ['passed' => false, 'reason' => 'رقم الإجابة الصحيحة خارج النطاق (يجب أن يكون بين 0 و 3)'];
        }

        // 4. خيارات فريدة وغير فارغة
        $trimmedOptions = array_map('trim', $options);
        if (in_array('', $trimmedOptions, true)) {
            return ['passed' => false, 'reason' => 'توجد خيارات فارغة'];
        }

        $uniqueOptions = array_unique(array_map([ArabicNormalizer::class, 'normalize'], $trimmedOptions));
        if (count($uniqueOptions) !== 4) {
            return ['passed' => false, 'reason' => 'توجد خيارات متطابقة أو مكررة في المعنى بعد التطبيع'];
        }

        // 5. فحص العبارات الشاذة في الخيارات ("كل ما سبق"، "لا شيء مما سبق")
        foreach ($trimmedOptions as $opt) {
            if (preg_match('/(كل ما سبق|جميع ما سبق|لا شيء مما سبق|لا توجد إجابة)/u', $opt)) {
                return ['passed' => false, 'reason' => 'يحتوي خياراً على عبارات شاذة مرفوضة (مثل كل ما سبق أو لا شيء)'];
            }
        }

        // 6. نص السؤال لا يحتوي على الإجابة الصحيحة صراحة
        $correctAnswer = $trimmedOptions[$correctIndex];
        if (mb_strlen($correctAnswer) >= 3) {
            $normPrompt = ArabicNormalizer::normalize($prompt);
            $normAnswer = ArabicNormalizer::normalize($correctAnswer);
            if (str_contains($normPrompt, $normAnswer)) {
                return ['passed' => false, 'reason' => 'نص السؤال يحتوي صراحة على الإجابة الصحيحة'];
            }
        }

        // 7. السؤال مفرد وليس مركباً (سؤالان في سؤال)
        $qMarkCount = mb_substr_count($prompt, '؟') + mb_substr_count($prompt, '?');
        if ($qMarkCount > 1 || preg_match('/(و\s*(من|ما|متى|أين|كم|كيف|أي))/u', $prompt)) {
            return ['passed' => false, 'reason' => 'السؤال مركب ويجمع أكثر من سؤال في آن واحد'];
        }

        // 8. منع الأرقام المتغيرة والإحصائيات غير الثابتة
        foreach (self::FORBIDDEN_DYNAMIC_PATTERNS as $pattern) {
            if (preg_match($pattern, $prompt)) {
                return ['passed' => false, 'reason' => 'السؤال يعتمد على إحصائيات متغيرة أو زمنية (أرقام قياسية أو وضع حالي)'];
            }
        }

        return ['passed' => true, 'reason' => null];
    }

    protected function cleanJson(string $raw): string
    {
        $raw = trim($raw);
        if (preg_match('/```json\s*(.*?)\s*```/s', $raw, $matches)) {
            $raw = $matches[1];
        } elseif (preg_match('/```\s*(.*?)\s*```/s', $raw, $matches)) {
            $raw = $matches[1];
        }
        return trim($raw);
    }
}
