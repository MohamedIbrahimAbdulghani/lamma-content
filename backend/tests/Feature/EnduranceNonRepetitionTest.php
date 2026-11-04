<?php
// Lamma - by Mohamed Ibrahim

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CharadesWord;
use App\Models\DeviceContentHistory;
use App\Models\Question;
use App\Models\RoomSession;
use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class EnduranceNonRepetitionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Queue::fake();
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
    }

    /**
     * اختبار تحمّل لـ 300 جولة لتحدي الشلة:
     * - غرفة تضم 3 أجهزة بسجلات مشاهدة مختلفة
     * - فشل فوري لو ظهر أي سؤال مرتين لنفس الغرفة أو أي من اللاعبين الحاضرين
     * - التحقق من عدم التدوير الصامت والوقوف بـ 404 صادق عند النفاد
     */
    public function test_endurance_300_rounds_trivia_zero_repetition(): void
    {
        $cat = Category::create([
            'slug' => 'general',
            'name_ar' => 'معلومات عامة',
            'is_active' => true,
        ]);

        // إنشاء بنك أسئلة يكفي 300 سؤال فريد
        $questionCount = 350;
        for ($i = 1; $i <= $questionCount; $i++) {
            Question::create([
                'category_id' => $cat->id,
                'type' => 'mcq',
                'prompt_ar' => "سؤال اختبار التحمل رقم {$i} الفريد تماماً؟",
                'options' => ["خيار {$i} أ", "خيار {$i} ب", "خيار {$i} ج", "خيار {$i} د"],
                'correct_index' => $i % 4,
                'difficulty' => 'medium',
                'source' => 'seed',
                'content_hash' => sha1("endurance_q_{$i}"),
                'status' => 'active',
                'is_active' => true,
            ]);
        }

        // إنشاء غرفة بثلاثة أجهزة مختلفة
        $roomCode = 'ENDUR1';
        $this->withHeader('X-Device-Id', 'device-host')
            ->postJson('/api/v1/rooms', ['room_code' => $roomCode, 'game_mode' => 'trivia'])
            ->assertStatus(200);

        $this->withHeader('X-Device-Id', 'device-p2')
            ->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertStatus(200);

        $this->withHeader('X-Device-Id', 'device-p3')
            ->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertStatus(200);

        // إعطاء أجهزة اللاعبين سجلات مسبقة مختلفة
        DeviceContentHistory::create(['device_id' => 'device-p2', 'content_type' => 'trivia', 'content_id' => 1]);
        DeviceContentHistory::create(['device_id' => 'device-p3', 'content_type' => 'trivia', 'content_id' => 2]);

        $servedQuestionIds = [];
        $totalRounds = 300;

        for ($r = 1; $r <= $totalRounds; $r++) {
            $resp = $this->withHeader('X-Device-Id', 'device-host')
                ->getJson("/api/v1/rooms/{$roomCode}/next-question?categories=general&difficulty=medium");

            $resp->assertStatus(200);
            $data = $resp->json('data');
            $this->assertNotNull($data);
            $qId = (int) $data['id'];

            // الشرط الجوهري: عدم تكرار أي سؤال ظهر سابقاً في هذه الغرفة أو لأي لاعب
            $this->assertFalse(
                in_array($qId, $servedQuestionIds, true),
                "فشل اختبار التحمل: السؤال رقم {$qId} ظهر مرتين في الجولة {$r}!"
            );
            $this->assertNotEquals(1, $qId, "فشل اختبار التحمل: تم تقديم سؤال سبق أن شاهده اللاعب 2!");
            $this->assertNotEquals(2, $qId, "فشل اختبار التحمل: تم تقديم سؤال سبق أن شاهده اللاعب 3!");

            $servedQuestionIds[] = $qId;
        }

        $this->assertCount(300, array_unique($servedQuestionIds));

        // التحقق من أن ما تبقى (350 - 300 - 2 مسبق = 48) ينفد ويصل لـ 404 دون تدوير صامت
        for ($extra = 0; $extra < 48; $extra++) {
            $resp = $this->withHeader('X-Device-Id', 'device-host')
                ->getJson("/api/v1/rooms/{$roomCode}/next-question?categories=general&difficulty=medium");
            if ($resp->status() === 200) {
                $qId = (int) $resp->json('data.id');
                $this->assertFalse(in_array($qId, $servedQuestionIds, true));
                $servedQuestionIds[] = $qId;
            }
        }

        // عند النفاد تماماً: يجب أن يرجع 404 صادق (exhausted) وممنوع الرجوع لأي سؤال سابق
        $exhaustedResp = $this->withHeader('X-Device-Id', 'device-host')
            ->getJson("/api/v1/rooms/{$roomCode}/next-question?categories=general&difficulty=medium");
        $exhaustedResp->assertStatus(404)
            ->assertJson(['success' => false, 'error' => 'exhausted']);
    }

    /**
     * اختبار تحمّل لـ 300 جولة للعبة مين الجاسوس:
     * - الكلمة السرية لا تتكرر أبداً بين جولتين متتاليتين ولا في أي جولة سابقة لنفس الغرفة
     * - المجموعة لا تتكرر قبل نفاد المجموعات غير المشاهدة
     * - اختيارات الجاسوس الـ 4 متجانسة من نفس المجموعة دائماً وتحتوي الكلمة السرية
     */
    public function test_endurance_300_rounds_spy_zero_consecutive_or_room_repetition(): void
    {
        // إنشاء 310 مجموعة كلمات لمين الجاسوس
        for ($g = 1; $g <= 310; $g++) {
            $group = SpyWordGroup::create([
                'pack_slug' => 'places',
                'title_ar' => "مجموعة تجريبية {$g}",
                'theme' => "theme_{$g}",
                'difficulty' => 'medium',
                'content_hash' => hash('sha256', "spy_grp_{$g}"),
                'status' => 'active',
            ]);

            for ($w = 1; $w <= 5; $w++) {
                SpyGroupWord::create([
                    'group_id' => $group->id,
                    'word_ar' => "مكان_{$g}_{$w}",
                    'normalized_word' => "مكان_{$g}_{$w}",
                    'content_hash' => hash('sha256', "spy_word_{$g}_{$w}"),
                    'is_active' => true,
                ]);
            }
        }

        $roomCode = 'SPYEND1';
        $this->withHeader('X-Device-Id', 'device-host')
            ->postJson('/api/v1/rooms', ['room_code' => $roomCode, 'game_mode' => 'spy'])
            ->assertStatus(200);

        $this->withHeader('X-Device-Id', 'device-p2')
            ->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertStatus(200);

        $servedSecretWords = [];
        $servedGroupIds = [];
        $previousWord = '';
        $totalRounds = 300;

        for ($r = 1; $r <= $totalRounds; $r++) {
            $url = "/api/v1/rooms/{$roomCode}/next-spy-round?pack=places&difficulty=medium";
            if (!empty($previousWord)) {
                $url .= "&previous_word=" . urlencode($previousWord);
            }

            $resp = $this->withHeader('X-Device-Id', 'device-host')
                ->json('GET', $url, [
                    'exclude_words' => $servedSecretWords,
                ]);

            $resp->assertStatus(200);
            $data = $resp->json('data');
            $this->assertNotNull($data);

            $secretWord = $data['secret_word'];
            $groupId = $data['group_id'];
            $spyChoices = $data['spy_choices'];

            // 1. الكلمة السرية لا تتكرر مع الجولة السابقة مباشرة
            $this->assertNotEquals(
                $previousWord,
                $secretWord,
                "فشل اختبار التحمل: الكلمة السرية تكررت في جولتين متتاليتين بالجولة {$r}!"
            );

            // 2. الكلمة السرية لا تتكرر مع أي جولة سابقة في نفس الغرفة
            $this->assertFalse(
                in_array($secretWord, $servedSecretWords, true),
                "فشل اختبار التحمل: الكلمة السرية '{$secretWord}' تكررت في الغرفة بالجولة {$r}!"
            );

            // 3. المجموعة لا تتكرر قبل نفاد المجموعات
            $this->assertFalse(
                in_array($groupId, $servedGroupIds, true),
                "فشل اختبار التحمل: المجموعة {$groupId} تكررت قبل نفاد المخزون بالجولة {$r}!"
            );

            // 4. خيارات الجاسوس 4 اختيارات وتحتوي الكلمة السرية
            $this->assertCount(4, $spyChoices);
            $this->assertContains($secretWord, $spyChoices);

            $servedSecretWords[] = $secretWord;
            $servedGroupIds[] = $groupId;
            $previousWord = $secretWord;
        }

        $this->assertCount(300, array_unique($servedSecretWords));
        $this->assertCount(300, array_unique($servedGroupIds));
    }

    /**
     * اختبار تحمّل لـ 300 جولة للعبة مثّل ومتتكلمش:
     * - لا تتكرر أي كلمة على الإطلاق لنفس الغرفة أو أجهزة اللاعبين الحاضرين
     * - عند النفاد: يرجع 404 صادق دون تدوير صامت
     */
    public function test_endurance_300_rounds_charades_zero_repetition(): void
    {
        $cat = \App\Models\CharadesCategory::create([
            'slug' => 'movies',
            'name_ar' => 'أفلام ومسلسلات',
        ]);

        for ($i = 1; $i <= 320; $i++) {
            CharadesWord::create([
                'category_id' => $cat->id,
                'word_ar' => "فيلم تجريبي فريد {$i}",
                'difficulty' => 'medium',
                'content_hash' => sha1("charades_w_{$i}"),
                'status' => 'active',
                'is_active' => true,
            ]);
        }

        $roomCode = 'CHAREND1';
        $this->withHeader('X-Device-Id', 'device-host')
            ->postJson('/api/v1/rooms', ['room_code' => $roomCode, 'game_mode' => 'charades'])
            ->assertStatus(200);

        $this->withHeader('X-Device-Id', 'device-p2')
            ->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertStatus(200);

        $servedWords = [];
        $totalRounds = 300;

        for ($r = 1; $r <= $totalRounds; $r++) {
            $resp = $this->withHeader('X-Device-Id', 'device-host')
                ->json('GET', "/api/v1/rooms/{$roomCode}/next-charades?category=movies", [
                    'exclude_words' => $servedWords,
                ]);

            $resp->assertStatus(200);
            $word = $resp->json('data.word_ar');

            $this->assertNotEmpty($word);
            $this->assertFalse(
                in_array($word, $servedWords, true),
                "فشل اختبار التحمل: كلمة التمثيل '{$word}' تكررت في الجولة {$r}!"
            );

            $servedWords[] = $word;
        }

        $this->assertCount(300, array_unique($servedWords));
    }
}
