<?php
// Lamma - by Mohamed Ibrahim

namespace Tests\Feature;

use App\Services\GenerateAiContentService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AiContentGenerationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        Config::set('services.gemini.key', 'TEST_GEMINI_KEY');
        Config::set('services.gemini.model', 'gemini-3.5-flash-lite');
    }

    public function test_configuration_does_not_contain_2_5_model(): void
    {
        $defaultConfig = config('services.gemini.model');
        $this->assertStringNotContainsString('2.5', $defaultConfig);
        $this->assertStringNotContainsString('2.5', GenerateAiContentService::DEFAULT_MODEL);

        foreach (GenerateAiContentService::FALLBACK_MODELS as $model) {
            $this->assertStringNotContainsString('2.5', $model);
        }
    }

    public function test_ai_health_endpoint_returns_ok_when_key_configured(): void
    {
        $response = $this->getJson('/api/v1/ai/health');

        $response->assertStatus(200)
            ->assertJson([
                'healthy' => true,
                'backend_proxy' => true,
                'model' => 'gemini-3.5-flash-lite',
            ]);
    }

    public function test_ai_health_endpoint_returns_503_when_key_is_missing(): void
    {
        Config::set('services.gemini.key', null);

        $response = $this->getJson('/api/v1/ai/health');

        $response->assertStatus(503)
            ->assertJson([
                'healthy' => false,
                'backend_proxy' => true,
            ]);
    }

    public function test_content_generation_returns_401_when_key_missing(): void
    {
        Config::set('services.gemini.key', null);

        $response = $this->postJson('/api/v1/content/generate', [
            'game_type' => 'trivia',
            'count' => 5,
        ]);

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'error_code' => 'INVALID_KEY',
            ]);
    }

    public function test_content_generation_succeeds_with_mocked_gemini_response(): void
    {
        $mockQuestions = [
            [
                'type' => 'mcq',
                'prompt_ar' => 'ما هي عاصمة جمهورية مصر العربية؟',
                'options' => ['القاهرة', 'الإسكندرية', 'الجيزة', 'أسوان'],
                'correct_index' => 0,
                'category_slug' => 'general',
                'difficulty' => 'easy',
            ]
        ];

        Http::fake([
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                ['text' => json_encode($mockQuestions)]
                            ]
                        ]
                    ]
                ]
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/content/generate', [
            'game_type' => 'trivia',
            'count' => 1,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'game_type' => 'trivia',
                'count' => 1,
            ]);

        $this->assertEquals('ما هي عاصمة جمهورية مصر العربية؟', $response->json('data.0.prompt_ar'));
    }

    public function test_content_generation_404_auto_discovers_fallback_model(): void
    {
        Config::set('services.gemini.model', 'invalid-old-model');

        Http::fake([
            // الموديل القديم يرجع 404 مع نصيحة جوجل
            'https://generativelanguage.googleapis.com/v1beta/models/invalid-old-model:generateContent*' => Http::response([
                'error' => [
                    'code' => 404,
                    'message' => 'This model models/invalid-old-model is no longer available, use models/gemini-3.5-flash-lite',
                ]
            ], 404),
            // فحص صحة الموديل المقترح gemini-3.5-flash-lite ينجح
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                ['text' => json_encode([
                                    [
                                        'type' => 'mcq',
                                        'prompt_ar' => 'سؤال مولد بالموديل البديل',
                                        'options' => ['اختيار 1', 'اختيار 2', 'اختيار 3', 'اختيار 4'],
                                        'correct_index' => 0,
                                        'category_slug' => 'general',
                                        'difficulty' => 'medium',
                                    ]
                                ])]
                            ]
                        ]
                    ]
                ]
            ], 200),
        ]);

        $response = $this->postJson('/api/v1/content/generate', [
            'game_type' => 'trivia',
            'count' => 1,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'count' => 1,
            ]);

        // تم حفظ الموديل الفعال في الكاش
        $cached = Cache::get(GenerateAiContentService::CACHE_KEY);
        $this->assertIsArray($cached);
        $this->assertEquals('gemini-3.5-flash-lite', $cached['effective_model']);
    }

    public function test_content_generation_400_retries_with_simpler_configuration(): void
    {
        $attempt = 0;
        Http::fake([
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent*' => function ($request) use (&$attempt) {
                $attempt++;
                if ($attempt === 1) {
                    return Http::response([
                        'error' => [
                            'code' => 400,
                            'message' => 'Request contains an invalid argument: thinkingConfig is not supported',
                        ]
                    ], 400);
                }
                return Http::response([
                    'candidates' => [
                        [
                            'content' => [
                                'parts' => [
                                    ['text' => json_encode([
                                        [
                                            'type' => 'mcq',
                                            'prompt_ar' => 'سؤال نجح بعد إعادة المحاولة بدون thinkingConfig',
                                            'options' => ['أ', 'ب', 'ج', 'د'],
                                            'correct_index' => 2,
                                            'category_slug' => 'general',
                                            'difficulty' => 'easy',
                                        ]
                                    ])]
                                ]
                            ]
                        ]
                    ]
                ], 200);
            },
        ]);

        $response = $this->postJson('/api/v1/content/generate', [
            'game_type' => 'trivia',
            'count' => 1,
        ]);

        $response->assertStatus(200);
        $this->assertEquals(2, $attempt, 'يجب أن يعيد المحاولة بإعدادات أبسط عند 400');
    }

    public function test_old_cache_never_overrides_newly_configured_env_model(): void
    {
        $service = app(GenerateAiContentService::class);

        // وضع كاش قديم مربوط بـ gemini-3.5-flash-lite
        Cache::put(GenerateAiContentService::CACHE_KEY, [
            'configured_model' => 'gemini-3.5-flash-lite',
            'effective_model' => 'gemini-flash-lite-latest',
            'tested_at' => now()->toIso8601String(),
        ], now()->addDay());

        // إذا كان الموديل المطلوب في الإعدادات مطابق، يُستخدم الكاش
        Config::set('services.gemini.model', 'gemini-3.5-flash-lite');
        $this->assertEquals('gemini-flash-lite-latest', $service->getActiveModel());

        // إذا قام المطور بتغيير .env إلى موديل جديد، يجب إبطال الكاش واعتماد الموديل الجديد فوراً
        Config::set('services.gemini.model', 'gemini-3.8-flash');
        $this->assertEquals('gemini-3.8-flash', $service->getActiveModel());
        $this->assertNull(Cache::get(GenerateAiContentService::CACHE_KEY));
    }
}
