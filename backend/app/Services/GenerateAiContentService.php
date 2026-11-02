<?php
// Lamma - by Mohamed Ibrahim

namespace App\Services;

use App\Exceptions\AiServiceException;
use App\Helpers\ArabicTextNormalizer;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GenerateAiContentService
{
    /**
     * الموديل الأساسي الافتراضي المعتمد (سريع، مستقر، ويدعم العربية بكفاءة عالية)
     */
    public const DEFAULT_MODEL = 'gemini-3.5-flash-lite';

    /**
     * مفتاح تخزين الموديل الفعال في الكاش
     */
    public const CACHE_KEY = 'lamma_active_gemini_model_v2';

    /**
     * قائمة الموديلات الاحتياطية السريعة المرتبة حسب الأولوية
     */
    public const FALLBACK_MODELS = [
        'gemini-3.5-flash-lite',
        'gemini-flash-lite-latest',
        'gemini-3.8-flash',
        'gemini-flash-latest',
    ];

    /**
     * الكلمات الدلالية لاستبعاد الموديلات غير المناسبة (صوت، صور، روبوتات، ونماذج قديمة غير متاحة)
     */
    public const EXCLUDED_KEYWORDS = [
        'tts',
        'image',
        'lyria',
        'transcribe',
        'robotics',
        'computer-use',
        'embedding',
        'aqa',
        '2.5',
    ];

    /**
     * تجريد أي بادئة models/ أو مسافات زائدة
     */
    public static function sanitizeModel(string $model): string
    {
        $cleaned = trim($model);
        while (str_starts_with($cleaned, 'models/')) {
            $cleaned = trim(substr($cleaned, 7));
        }
        return $cleaned;
    }

    /**
     * تنظيف أي ظهور لمفتاح API في النصوص والروابط
     */
    public static function sanitizeMessage(string $message): string
    {
        return preg_replace('/key=[^&\s]+/i', 'key=[HIDDEN]', $message) ?? $message;
    }

    /**
     * قراءة الموديل الفعال مع أولوية مطلقة لإعدادات .env الجديدة:
     * 1. فحص الموديل المطلوب في الإعدادات config('services.gemini.model')
     * 2. الكاش يُعتمد فقط إذا كان الموديل المطلوب في الإعدادات مطابقاً لما تم اختباره مسبقاً
     * 3. إذا تغير الإعداد في .env يتم إبطال الكاش فوراً والبدء من القيمة الجديدة
     */
    public function getActiveModel(): string
    {
        $configured = self::sanitizeModel((string) (config('services.gemini.model') ?: self::DEFAULT_MODEL));

        $cached = Cache::get(self::CACHE_KEY);
        if (is_array($cached) && isset($cached['configured_model'], $cached['effective_model'])) {
            // الكاش صالح فقط إذا لم تتغير قيمة الموديل في الإعدادات
            if ($cached['configured_model'] === $configured && !empty($cached['effective_model'])) {
                return self::sanitizeModel((string) $cached['effective_model']);
            }
            // إذا تغيرت الإعدادات، يتم إبطال الكاش فوراً
            Cache::forget(self::CACHE_KEY);
        }

        return $configured;
    }

    /**
     * اختبار صحة موديل معين بطلب generateContent حقيقي صغير (بدون الاعتماد على مجرد وجوده في القائمة)
     */
    public function testModelHealth(string $model, string $apiKey, int $timeoutSeconds = 8): array
    {
        $cleanModel = self::sanitizeModel($model);
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$cleanModel}:generateContent?key={$apiKey}";

        $payload = [
            'contents' => [
                [
                    'role' => 'user',
                    'parts' => [
                        ['text' => 'ping'],
                    ],
                ],
            ],
            'generationConfig' => [
                'temperature' => 0.2,
                'maxOutputTokens' => 10,
            ],
        ];

        $start = microtime(true);
        try {
            $response = Http::timeout($timeoutSeconds)->post($url, $payload);
            $elapsedMs = round((microtime(true) - $start) * 1000, 1);
            $status = $response->status();

            // إذا كان 400، نعيد المحاولة مرة واحدة بدون generationConfig
            if ($status === 400) {
                $retryResponse = Http::timeout($timeoutSeconds)->post($url, [
                    'contents' => $payload['contents'],
                ]);
                if ($retryResponse->successful()) {
                    return [
                        'ok' => true,
                        'status' => 200,
                        'suggested_model' => null,
                        'error' => null,
                        'latency_ms' => round((microtime(true) - $start) * 1000, 1),
                    ];
                }
                $status = $retryResponse->status();
                $response = $retryResponse;
            }

            if ($response->successful()) {
                return [
                    'ok' => true,
                    'status' => $status,
                    'suggested_model' => null,
                    'error' => null,
                    'latency_ms' => $elapsedMs,
                ];
            }

            $rawError = $response->json('error.message') ?? $response->body();
            $cleanError = self::sanitizeMessage((string) $rawError);

            // استخراج أي موديل بديل مقترح من جوجل عند حدوث 404 (use models/X)
            $suggested = null;
            if ($status === 404 && preg_match('/use models\/([a-zA-Z0-9_\.\-]+)/i', $rawError, $matches)) {
                $suggested = self::sanitizeModel($matches[1]);
            }

            return [
                'ok' => false,
                'status' => $status,
                'suggested_model' => $suggested,
                'error' => $cleanError,
                'latency_ms' => $elapsedMs,
            ];
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'status' => 504,
                'suggested_model' => null,
                'error' => self::sanitizeMessage($e->getMessage()),
                'latency_ms' => round((microtime(true) - $start) * 1000, 1),
            ];
        }
    }

    /**
     * اكتشاف واختيار أفضل موديل بديل يعمل فعلياً وحفظه في الكاش لمدة 24 ساعة
     */
    public function discoverAndSwitchWorkingModel(string $apiKey, ?string $failedModel = null, ?string $suggestedModel = null): ?string
    {
        $configured = self::sanitizeModel((string) (config('services.gemini.model') ?: self::DEFAULT_MODEL));

        // بناء قائمة المرشحين حسب الأولوية الصارمة:
        // 1. الموديل البديل المقترح من رد جوجل 404 إن وُجد
        // 2. الموديل المطلوب في الإعدادات
        // 3. القائمة الاحتياطية المعتمدة
        $candidates = [];
        if (!empty($suggestedModel)) {
            $candidates[] = self::sanitizeModel($suggestedModel);
        }
        $candidates[] = $configured;
        foreach (self::FALLBACK_MODELS as $fb) {
            if (!in_array($fb, $candidates, true)) {
                $candidates[] = $fb;
            }
        }

        // اختبار المرشحين واحداً تلو الآخر بطلب generateContent حقيقي
        foreach ($candidates as $cand) {
            if ($failedModel !== null && $cand === self::sanitizeModel($failedModel)) {
                continue;
            }

            $probe = $this->testModelHealth($cand, $apiKey, timeoutSeconds: 6);
            if ($probe['ok']) {
                $this->cacheWorkingModel($configured, $cand);
                Log::info("تم اعتماد الموديل البديل الناجح: {$cand} (بعد فشل {$failedModel})");
                return $cand;
            }
        }

        // في حال فشل كل المرشحين المعروفين، نحاول الاستعلام عن GET /v1beta/models
        try {
            $url = "https://generativelanguage.googleapis.com/v1beta/models?key={$apiKey}";
            $res = Http::timeout(6)->get($url);
            if ($res->successful()) {
                $models = (array) ($res->json('models') ?? []);
                foreach ($models as $item) {
                    if (!is_array($item)) continue;
                    $name = self::sanitizeModel((string) ($item['name'] ?? ''));
                    $lower = strtolower($name);

                    $methods = (array) ($item['supportedGenerationMethods'] ?? []);
                    if (!in_array('generateContent', $methods, true) || !str_contains($lower, 'flash')) {
                        continue;
                    }

                    $excluded = false;
                    foreach (self::EXCLUDED_KEYWORDS as $kw) {
                        if (str_contains($lower, $kw)) {
                            $excluded = true;
                            break;
                        }
                    }
                    if ($excluded || in_array($name, $candidates, true) || $name === $failedModel) {
                        continue;
                    }

                    // اختبار الموديل المستكشف قبل اعتماده
                    $probe = $this->testModelHealth($name, $apiKey, timeoutSeconds: 6);
                    if ($probe['ok']) {
                        $this->cacheWorkingModel($configured, $name);
                        Log::info("تم اكتشاف واعتماد موديل Flash جديد من جوجل: {$name}");
                        return $name;
                    }
                }
            }
        } catch (\Throwable $e) {
            Log::warning('تعذر استعلام قائمة الموديلات من Google: ' . self::sanitizeMessage($e->getMessage()));
        }

        return null;
    }

    /**
     * حفظ الموديل المعتمد في الكاش مع ربطه بالموديل المطلوب في الإعدادات وتاريخ الاختبار
     */
    public function cacheWorkingModel(string $configuredModel, string $effectiveModel): void
    {
        Cache::put(self::CACHE_KEY, [
            'configured_model' => self::sanitizeModel($configuredModel),
            'effective_model' => self::sanitizeModel($effectiveModel),
            'tested_at' => now()->toIso8601String(),
        ], now()->addHours(24));
    }

    /**
     * إبطال كاش الموديل الفعال
     */
    public function forgetActiveModelCache(): void
    {
        Cache::forget(self::CACHE_KEY);
        Cache::forget('discovered_gemini_model'); // إزالة أي كاش قديم متبقي
    }

    /**
     * فحص صحة واستعداد السلسلة للاختبار وEndpoint الصحي
     */
    public function checkHealth(): array
    {
        $apiKey = config('services.gemini.key');
        if (empty($apiKey)) {
            return [
                'healthy' => false,
                'message' => 'مفتاح Gemini API غير معين في ملف .env الخاص بالـ backend',
                'model' => null,
                'backend_proxy' => true,
            ];
        }

        $activeModel = $this->getActiveModel();

        return [
            'healthy' => true,
            'message' => 'سلسلة الذكاء الاصطناعي متصلة وجاهزة عبر Backend Proxy',
            'model' => $activeModel,
            'backend_proxy' => true,
        ];
    }

    /**
     * توليد محتوى ألعاب بالذكاء الاصطناعي مع منع التكرار والتطبيع الصارم
     */
    public function generate(
        string $gameType,
        ?string $category = null,
        int $count = 20,
        array $excludeItems = [],
        ?string $difficulty = null,
        array $categories = []
    ): array {
        $apiKey = config('services.gemini.key');
        if (empty($apiKey)) {
            throw new AiServiceException(
                message: 'مفتاح Gemini API غير معين في ملف .env الخاص بالـ backend.',
                statusCode: 401,
                errorCode: 'INVALID_KEY',
                debugInfo: ['source' => 'Backend', 'details' => 'GEMINI_API_KEY is empty in config']
            );
        }

        // تجهيز قائمة المستبعدات بعد التطبيع
        $normalizedExcludes = [];
        foreach ($excludeItems as $item) {
            if (!empty($item)) {
                $normalizedExcludes[ArabicTextNormalizer::normalize((string) $item)] = true;
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

        // إعدادات التوليد السريعة المتوافقة تماماً مع نماذج Flash
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
                'maxOutputTokens' => 2048,
            ],
        ];

        $currentModel = $this->getActiveModel();
        $hasAttemptedFallback = false;
        $hasRetried400 = false;
        $hasRetriedRateLimit = false;

        while (true) {
            $url = "https://generativelanguage.googleapis.com/v1beta/models/{$currentModel}:generateContent?key={$apiKey}";

            try {
                $response = Http::timeout(25)->post($url, $body);

                if ($response->successful()) {
                    $data = $response->json();
                    $rawText = $data['candidates'][0]['content']['parts'][0]['text'] ?? '';

                    if (empty($rawText)) {
                        throw new AiServiceException(
                            message: 'رد فارغ أو غير صالح من الذكاء الاصطناعي.',
                            statusCode: 502,
                            errorCode: 'INVALID_RESPONSE',
                            debugInfo: ['source' => 'Gemini', 'status' => 200, 'model' => $currentModel]
                        );
                    }

                    $cleanJson = preg_replace('/^```(?:json)?\s*/i', '', trim($rawText));
                    $cleanJson = preg_replace('/\s*```$/', '', (string) $cleanJson);

                    $decoded = json_decode((string) $cleanJson, true);
                    $items = is_array($decoded) ? ($decoded['items'] ?? $decoded) : [];

                    // تصفية المحتوى والتحقق الصارم من صحة الأسئلة ومنع التكرار
                    return $this->filterAndValidateItems(
                        gameType: $gameType,
                        items: (array) $items,
                        count: $count,
                        normalizedExcludes: $normalizedExcludes,
                        difficulty: $difficulty
                    );
                }

                $status = $response->status();
                $errBody = $response->body();
                $cleanErrBody = self::sanitizeMessage($errBody);

                // 1. معالجة 404 (الموديل غير متاح) واكتشاف الموديل البديل الذكي
                if ($status === 404 && !$hasAttemptedFallback) {
                    $hasAttemptedFallback = true;
                    $this->forgetActiveModelCache();

                    // فحص هل ردت جوجل باقتراح موديل بديل في الرسالة؟
                    $suggested = null;
                    if (preg_match('/use models\/([a-zA-Z0-9_\.\-]+)/i', $errBody, $m)) {
                        $suggested = self::sanitizeModel($m[1]);
                    }

                    Log::warning("الموديل {$currentModel} غير متاح (404). محاولة التبديل التلقائي لموديل Flash بديل...");
                    $newModel = $this->discoverAndSwitchWorkingModel($apiKey, failedModel: $currentModel, suggestedModel: $suggested);

                    if (!empty($newModel) && $newModel !== $currentModel) {
                        $currentModel = $newModel;
                        continue;
                    }
                }

                // 2. معالجة 400 (معاملات غير صالحة أو thinkingConfig أو المفتاح)
                if ($status === 400) {
                    if (str_contains($errBody, 'API_KEY_INVALID') || str_contains($errBody, 'not valid') || str_contains($errBody, 'KEY')) {
                        throw new AiServiceException(
                            message: 'مفتاح Gemini API غير صالح.',
                            statusCode: 401,
                            errorCode: 'INVALID_KEY',
                            debugInfo: ['source' => 'Gemini', 'status' => 400, 'details' => 'Invalid API Key']
                        );
                    }

                    // إعادة المحاولة مرة واحدة بإعدادات مبسطة بدون أي معلمات اختيارية
                    if (!$hasRetried400) {
                        $hasRetried400 = true;
                        $body['generationConfig'] = [
                            'temperature' => 0.5,
                            'responseMimeType' => 'application/json',
                        ];
                        continue;
                    }
                }

                // 3. معالجة 403 (أذونات المفتاح)
                if ($status === 403) {
                    throw new AiServiceException(
                        message: 'مفتاح Gemini API غير مصرح له باستخدام هذه الخدمة أو الموديل.',
                        statusCode: 403,
                        errorCode: 'FORBIDDEN',
                        debugInfo: ['source' => 'Gemini', 'status' => 403, 'details' => $cleanErrBody]
                    );
                }

                // 4. معالجة 429 (تجاوز حد الاستخدام) مع Backoff
                if ($status === 429) {
                    if (!$hasRetriedRateLimit) {
                        $hasRetriedRateLimit = true;
                        usleep(1500000); // 1.5 ثانية انتظار
                        continue;
                    }
                    throw new AiServiceException(
                        message: 'تم تجاوز حد استخدام الذكاء الاصطناعي مؤقتاً (429). يرجى الانتظار بضع ثوانٍ.',
                        statusCode: 429,
                        errorCode: 'RATE_LIMIT',
                        debugInfo: ['source' => 'Gemini', 'status' => 429, 'model' => $currentModel]
                    );
                }

                // 5. خطأ 404 بعد استنفاد كل البدائل
                if ($status === 404) {
                    throw new AiServiceException(
                        message: "موديل الذكاء الاصطناعي ({$currentModel}) غير متاح في الحساب (404).",
                        statusCode: 404,
                        errorCode: 'MODEL_NOT_FOUND',
                        debugInfo: ['source' => 'Gemini', 'status' => 404, 'model' => $currentModel]
                    );
                }

                // 6. أخطاء 5xx أو غيرها
                throw new AiServiceException(
                    message: "حدث خطأ أثناء التواصل مع الذكاء الاصطناعي ({$status}).",
                    statusCode: $status >= 500 ? 502 : $status,
                    errorCode: 'SERVICE_ERROR',
                    debugInfo: ['source' => 'Gemini', 'status' => $status, 'model' => $currentModel, 'details' => $cleanErrBody]
                );
            } catch (\Illuminate\Http\Client\ConnectionException $e) {
                // مهلة الاتصال
                if (!$hasAttemptedFallback) {
                    $hasAttemptedFallback = true;
                    // تجربة موديل بديل خفيف
                    $newModel = $this->discoverAndSwitchWorkingModel($apiKey, failedModel: $currentModel);
                    if (!empty($newModel) && $newModel !== $currentModel) {
                        $currentModel = $newModel;
                        continue;
                    }
                }
                throw new AiServiceException(
                    message: 'انتهت مهلة الاتصال بالذكاء الاصطناعي (Timeout).',
                    statusCode: 504,
                    errorCode: 'TIMEOUT',
                    debugInfo: ['source' => 'Backend/Gemini', 'details' => 'Connection timeout']
                );
            }
        }
    }

    /**
     * إرسال طلب نصي حر للذكاء الاصطناعي مع نفس آليات الموثوقية وتجاوز الأخطاء
     */
    public function generateRawContent(string $prompt, array $options = []): string
    {
        $apiKey = config('services.gemini.key');
        if (empty($apiKey)) {
            throw new AiServiceException(
                message: 'مفتاح Gemini API غير معين في ملف .env الخاص بالـ backend.',
                statusCode: 401,
                errorCode: 'INVALID_KEY',
                debugInfo: ['source' => 'Backend', 'details' => 'GEMINI_API_KEY is empty in config']
            );
        }

        $temperature = $options['temperature'] ?? 0.4;
        $maxOutputTokens = $options['maxOutputTokens'] ?? 2048;

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
                'temperature' => $temperature,
                'maxOutputTokens' => $maxOutputTokens,
            ],
        ];

        $currentModel = $this->getActiveModel();
        $hasAttemptedFallback = false;
        $hasRetried400 = false;
        $hasRetriedRateLimit = false;

        while (true) {
            $url = "https://generativelanguage.googleapis.com/v1beta/models/{$currentModel}:generateContent?key={$apiKey}";

            try {
                $response = Http::timeout(25)->post($url, $body);

                if ($response->successful()) {
                    $data = $response->json();
                    return $data['candidates'][0]['content']['parts'][0]['text'] ?? '';
                }

                $status = $response->status();
                $errBody = $response->body();

                if ($status === 404 && !$hasAttemptedFallback) {
                    $hasAttemptedFallback = true;
                    $this->forgetActiveModelCache();

                    $suggested = null;
                    if (preg_match('/use models\/([a-zA-Z0-9_\.\-]+)/i', $errBody, $m)) {
                        $suggested = self::sanitizeModel($m[1]);
                    }

                    $newModel = $this->discoverAndSwitchWorkingModel($apiKey, failedModel: $currentModel, suggestedModel: $suggested);
                    if (!empty($newModel) && $newModel !== $currentModel) {
                        $currentModel = $newModel;
                        continue;
                    }
                }

                if ($status === 400 && !$hasRetried400) {
                    $hasRetried400 = true;
                    unset($body['generationConfig']['thinkingConfig']);
                    continue;
                }

                if ($status === 429 && !$hasRetriedRateLimit) {
                    $hasRetriedRateLimit = true;
                    usleep(1500000);
                    continue;
                }

                throw new AiServiceException(
                    message: "حدث خطأ أثناء التواصل مع الذكاء الاصطناعي ({$status}).",
                    statusCode: $status >= 500 ? 502 : $status,
                    errorCode: 'SERVICE_ERROR',
                    debugInfo: ['source' => 'Gemini', 'status' => $status, 'model' => $currentModel]
                );
            } catch (\Illuminate\Http\Client\ConnectionException $e) {
                if (!$hasAttemptedFallback) {
                    $hasAttemptedFallback = true;
                    $newModel = $this->discoverAndSwitchWorkingModel($apiKey, failedModel: $currentModel);
                    if (!empty($newModel) && $newModel !== $currentModel) {
                        $currentModel = $newModel;
                        continue;
                    }
                }
                throw new AiServiceException(
                    message: 'انتهت مهلة الاتصال بالذكاء الاصطناعي (Timeout).',
                    statusCode: 504,
                    errorCode: 'TIMEOUT',
                    debugInfo: ['source' => 'Backend/Gemini', 'details' => 'Connection timeout']
                );
            }
        }
    }

    private function filterAndValidateItems(
        string $gameType,
        array $items,
        int $count,
        array $normalizedExcludes,
        ?string $difficulty
    ): array {
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

            if ($gameType === 'trivia') {
                $options = $item['options'] ?? null;
                if (!is_array($options) || count($options) !== 4) {
                    continue;
                }
                $trimmedOptions = array_map(fn($o) => trim((string)$o), $options);
                if (count(array_unique($trimmedOptions)) !== 4 || in_array('', $trimmedOptions, true)) {
                    continue;
                }
                $correctIndex = $item['correct_index'] ?? null;
                if (!is_int($correctIndex) || $correctIndex < 0 || $correctIndex > 3) {
                    continue;
                }
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
    ): string {
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
