<?php
// Lamma - by Mohamed Ibrahim

namespace Tests\Feature;

use App\Models\Category;
use App\Models\ContentReport;
use App\Models\Question;
use App\Models\RoomSession;
use App\Services\ContentVerificationService;
use App\Services\AutonomousContentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class StrictVerificationAndCategoryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        \Illuminate\Support\Facades\Queue::fake();
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);

        Category::firstOrCreate(['slug' => 'movies'], ['name_ar' => 'أفلام ومسلسلات', 'is_active' => true]);
        Category::firstOrCreate(['slug' => 'sports'], ['name_ar' => 'رياضة وكرة قدم', 'is_active' => true]);
        Category::firstOrCreate(['slug' => 'history'], ['name_ar' => 'تاريخ وجغرافيا', 'is_active' => true]);
        Category::firstOrCreate(['slug' => 'general'], ['name_ar' => 'معلومات عامة', 'is_active' => true]);
        Category::firstOrCreate(['slug' => 'afeehat'], ['name_ar' => 'إفيهات وأمثال', 'is_active' => true]);
    }

    /**
     * 1. رفض السؤال عند اختلاف الإجابة في التحقق الأعمى (Blind Verification Mismatch)
     */
    public function test_rejection_when_blind_verification_disagrees(): void
    {
        $verifier = app(ContentVerificationService::class);

        // Fake blind model returning 'الإسكندرية' instead of declared answer 'القاهرة'
        Http::fake([
            'https://generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'selected_option' => 'الإسكندرية',
                                        'confidence' => 95,
                                        'brief_reason' => 'إجابة مختلفة',
                                        'has_multiple_correct' => false,
                                        'has_ambiguity' => false,
                                    ])
                                ]
                            ]
                        ]
                    ]
                ]
            ], 200),
        ]);

        $item = [
            'prompt_ar' => 'ما هي عاصمة جمهورية مصر العربية؟',
            'options' => ['الإسكندرية', 'القاهرة', 'الجيزة', 'أسوان'],
            'correct_index' => 1,
            'category_slug' => 'general',
            'difficulty' => 'easy',
        ];

        $result = $verifier->verifyQuestion($item, 'general');

        $this->assertFalse($result['valid']);
        $this->assertStringContainsString('فشل التحقق الأعمى', $result['reason']);
    }

    /**
     * 2. رفض السؤال عند فشل التحقق أو انتهاء المهلة (Zero "trust the AI" fallback)
     */
    public function test_rejection_when_verification_fails_or_times_out(): void
    {
        $verifier = app(ContentVerificationService::class);

        // Fake network failure / 500 error from API
        Http::fake([
            'https://generativelanguage.googleapis.com/*' => Http::response(null, 500),
        ]);

        $item = [
            'prompt_ar' => 'ما هو أطول نهر في قارة أفريقيا والعالم؟',
            'options' => ['نهر النيل', 'نهر الأمازون', 'نهر الكونغو', 'نهر الميسيسيبي'],
            'correct_index' => 0,
            'category_slug' => 'history',
            'difficulty' => 'easy',
        ];

        $result = $verifier->verifyQuestion($item, 'history');

        $this->assertFalse($result['valid']);
        $this->assertStringContainsString('تعذر إتمام التحقق الأعمى', $result['reason']);
    }

    /**
     * 3. رفض الأسئلة المركبة والمتغيرة (Compound & Mutable)
     */
    public function test_rejection_of_compound_and_variable_or_mutable_questions(): void
    {
        $verifier = app(ContentVerificationService::class);

        // سؤال مركب به كلمتا استفهام "من و متى"
        $compound = [
            'prompt_ar' => 'من هو مؤسس الدولة الفاطمية ومتى تأسست؟',
            'options' => ['المعز لدين الله 969', 'جوهر الصقلي 969', 'صلاح الدين 1171', 'الفاطمي 909'],
            'correct_index' => 0,
            'category_slug' => 'history',
        ];
        $resCompound = $verifier->verifyQuestion($compound, 'history');
        $this->assertFalse($resCompound['valid']);
        $this->assertStringContainsString('سؤال مركب', $resCompound['reason']);

        // سؤال متغير يعتمد على إحصائية متغيرة أو "حاليا"
        $mutable = [
            'prompt_ar' => 'من هو هداف الدوري المصري حالياً للموسم الجاري؟',
            'options' => ['زيزو', 'وسام أبو علي', 'مابولولو', 'حسام أشرف'],
            'correct_index' => 1,
            'category_slug' => 'sports',
        ];
        $resMutable = $verifier->verifyQuestion($mutable, 'sports');
        $this->assertFalse($resMutable['valid']);
        $this->assertStringContainsString('متغيرة', $resMutable['reason']);

        // سؤال يحتوي نصه على الإجابة الصريحة
        $spoiler = [
            'prompt_ar' => 'في أي مدينة يقع برج إيفل في باريس؟',
            'options' => ['باريس', 'لندن', 'روما', 'مدريد'],
            'correct_index' => 0,
            'category_slug' => 'history',
        ];
        $resSpoiler = $verifier->verifyQuestion($spoiler, 'history');
        $this->assertFalse($resSpoiler['valid']);
        $this->assertStringContainsString('يحتوي صراحة على الإجابة', $resSpoiler['reason']);
    }

    /**
     * 4. عزل السؤال تلقائياً بعد بلاغين من جهازين مختلفين
     */
    public function test_auto_quarantine_after_two_distinct_device_reports(): void
    {
        $cat = Category::where('slug', 'movies')->first();
        $q = Question::create([
            'category_id' => $cat->id,
            'type' => 'mcq',
            'prompt_ar' => 'ما هو اسم بطل فيلم الكيف؟',
            'options' => ['د. بهاء', 'جمال', 'مزجانجي', 'سليم'],
            'correct_index' => 1,
            'status' => 'active',
            'is_active' => true,
        ]);

        // First report from Device A
        $r1 = $this->withHeader('X-Device-Id', 'device-A')
            ->postJson('/api/v1/content/report', [
                'content_type' => 'trivia',
                'content_id' => $q->id,
                'reason' => 'إجابة غير دقيقة',
            ]);
        $r1->assertStatus(200);

        $q->refresh();
        $this->assertEquals('active', $q->status, 'Question should not be quarantined after only 1 report');

        // Repeat report from SAME device A should NOT trigger quarantine
        $r1Repeat = $this->withHeader('X-Device-Id', 'device-A')
            ->postJson('/api/v1/content/report', [
                'content_type' => 'trivia',
                'content_id' => $q->id,
                'reason' => 'إجابة غير دقيقة تكرار',
            ]);
        $r1Repeat->assertStatus(200);

        $q->refresh();
        $this->assertEquals('active', $q->status, 'Repeated report from same device should not trigger quarantine');

        // Second report from Device B (distinct device) -> Auto Quarantine!
        $r2 = $this->withHeader('X-Device-Id', 'device-B')
            ->postJson('/api/v1/content/report', [
                'content_type' => 'trivia',
                'content_id' => $q->id,
                'reason' => 'إجابة غلط',
            ]);
        $r2->assertStatus(200);

        $q->refresh();
        $this->assertEquals('quarantined', $q->status, 'Question must be quarantined after 2 distinct device reports');
        $this->assertFalse((bool)$q->is_active);
        $this->assertStringContainsString('جهازين مختلفين', $q->rejection_reason);
    }

    /**
     * 5. قسم واحد لا ينتج أي سؤال من غيره عبر 500 اختيار متتالٍ
     */
    public function test_single_category_produces_no_foreign_questions_across_500_iterations(): void
    {
        $moviesCat = Category::where('slug', 'movies')->first();
        $sportsCat = Category::where('slug', 'sports')->first();

        // Seed 10 movies questions and 10 sports questions
        for ($i = 1; $i <= 10; $i++) {
            Question::create([
                'category_id' => $moviesCat->id,
                'type' => 'mcq',
                'prompt_ar' => "سؤال فيلم رقم $i لمخرج الفيلم الشهير؟",
                'options' => ['خيار 1', 'خيار 2', 'خيار 3', 'خيار 4'],
                'correct_index' => 0,
                'status' => 'active',
                'is_active' => true,
            ]);

            Question::create([
                'category_id' => $sportsCat->id,
                'type' => 'mcq',
                'prompt_ar' => "سؤال كورة رقم $i للنادي الرياضي؟",
                'options' => ['خيار 1', 'خيار 2', 'خيار 3', 'خيار 4'],
                'correct_index' => 0,
                'status' => 'active',
                'is_active' => true,
            ]);
        }

        for ($run = 1; $run <= 500; $run++) {
            $roomCode = "MOVIES_$run";
            RoomSession::create([
                'room_code' => $roomCode,
                'host_device_id' => "host-$run",
                'status' => 'active',
            ]);

            $resp = $this->withHeader('X-Device-Id', "device-tester-$run")
                ->getJson("/api/v1/rooms/$roomCode/next-question?categories=movies");

            $resp->assertStatus(200);
            $data = $resp->json('data');
            $this->assertNotNull($data, "Run $run returned null question");
            $this->assertEquals('movies', $data['category_slug'], "Violation: Run $run returned question from non-movies category!");
        }
    }

    /**
     * 6. تعدد الأقسام لا يتجاوز الأقسام المختارة
     */
    public function test_multi_category_never_exceeds_selected_categories(): void
    {
        $moviesCat = Category::where('slug', 'movies')->first();
        $sportsCat = Category::where('slug', 'sports')->first();
        $historyCat = Category::where('slug', 'history')->first();

        Question::create([
            'category_id' => $moviesCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال أفلام سينما؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);
        Question::create([
            'category_id' => $sportsCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رياضة ومباراة؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);
        Question::create([
            'category_id' => $historyCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال تاريخ وجغرافيا؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);

        $allowedSlugs = ['movies', 'sports'];

        for ($i = 1; $i <= 50; $i++) {
            $roomCode = "MULTI_$i";
            RoomSession::create([
                'room_code' => $roomCode,
                'host_device_id' => "host-$i",
                'status' => 'active',
            ]);

            $resp = $this->withHeader('X-Device-Id', "device-tester-$i")
                ->getJson("/api/v1/rooms/$roomCode/next-question?categories=movies,sports");

            $resp->assertStatus(200);
            $data = $resp->json('data');
            $this->assertContains($data['category_slug'], $allowedSlugs, "Returned category {$data['category_slug']} is outside chosen categories");
        }
    }

    /**
     * 7. اختيار "الكل" أو "خلط" يخلط من كل الأقسام
     */
    public function test_all_category_mixes_categories(): void
    {
        $moviesCat = Category::where('slug', 'movies')->first();
        $sportsCat = Category::where('slug', 'sports')->first();

        Question::create([
            'category_id' => $moviesCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال أفلام للكل؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);
        Question::create([
            'category_id' => $sportsCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رياضة للكل؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);

        $seenCategories = [];
        for ($i = 1; $i <= 50; $i++) {
            $roomCode = "ALL_$i";
            RoomSession::create([
                'room_code' => $roomCode,
                'host_device_id' => "host-$i",
                'status' => 'active',
            ]);

            $resp = $this->withHeader('X-Device-Id', "device-tester-$i")
                ->getJson("/api/v1/rooms/$roomCode/next-question?categories=all");

            $resp->assertStatus(200);
            $data = $resp->json('data');
            $seenCategories[$data['category_slug']] = true;
        }

        $this->assertGreaterThanOrEqual(2, count($seenCategories), "Choosing 'all' should mix across categories");
    }

    /**
     * 8. عدم وجود أي استعارة من قسم آخر عند النفاد
     */
    public function test_zero_cross_category_borrowing_on_exhaustion(): void
    {
        $historyCat = Category::where('slug', 'history')->first();

        // Put only 1 question in history
        $q = Question::create([
            'category_id' => $historyCat->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال وحيد في التاريخ والجغرافيا؟',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'status' => 'active',
            'is_active' => true,
        ]);

        $session = RoomSession::create([
            'room_code' => 'EXHAUST_TEST',
            'host_device_id' => 'host-device-1',
            'status' => 'active',
        ]);

        // First pick gets the question
        $resp1 = $this->withHeader('X-Device-Id', 'device-tester-1')
            ->getJson('/api/v1/rooms/EXHAUST_TEST/next-question?categories=history');
        $resp1->assertStatus(200);
        $this->assertEquals('history', $resp1->json('data.category_slug'));

        // Second pick with history exhausted and excluded hashes should NOT return movies/sports
        $pHash = md5('سؤال وحيد في التاريخ والجغرافيا؟');
        $resp2 = $this->withHeader('X-Device-Id', 'device-tester-1')
            ->getJson("/api/v1/rooms/EXHAUST_TEST/next-question?categories=history&exclude_hashes[]=$pHash");

        // It should either return 404 or history question, NEVER a sports or movies question!
        $data = $resp2->json('data');
        if ($data !== null) {
            $this->assertEquals('history', $data['category_slug'], "Exhaustion must never borrow from sports or movies!");
        } else {
            $this->assertTrue(in_array($resp2->status(), [200, 404]));
        }
    }

    /**
     * 9. توحيد المعرفات (Canonical Slugs)
     */
    public function test_unified_slug_matching_between_settings_storage_and_query(): void
    {
        $verifier = app(ContentVerificationService::class);

        $this->assertEquals('movies', $verifier->getCanonicalSlug('movies'));
        $this->assertEquals('movies', $verifier->getCanonicalSlug('أفلام'));
        $this->assertEquals('movies', $verifier->getCanonicalSlug('مسلسلات'));
        $this->assertEquals('sports', $verifier->getCanonicalSlug('كرة القدم'));
        $this->assertEquals('sports', $verifier->getCanonicalSlug('كورة'));
        $this->assertEquals('history', $verifier->getCanonicalSlug('تاريخ'));
        $this->assertEquals('general', $verifier->getCanonicalSlug('عام'));
        $this->assertEquals('afeehat', $verifier->getCanonicalSlug('إفيهات'));
    }
}
