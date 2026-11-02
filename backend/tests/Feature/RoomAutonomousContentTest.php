<?php
// Lamma - by Mohamed Ibrahim

namespace Tests\Feature;

use App\Models\Category;
use App\Models\DeviceContentHistory;
use App\Models\Question;
use App\Models\RoomSession;
use App\Models\SpyGroupWord;
use App\Models\SpyWordGroup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RoomAutonomousContentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Category::firstOrCreate(['slug' => 'general'], ['name_ar' => 'عام', 'is_active' => true]);
        $this->seed(\Database\Seeders\SpyWordGroupSeeder::class);
        \Illuminate\Support\Facades\Queue::fake();
    }

    public function test_room_session_creation_and_joining(): void
    {
        $response = $this->withHeader('X-Device-Id', 'device-host-1')
            ->postJson('/api/v1/rooms', [
                'room_code' => 'TEST99',
                'game_mode' => 'trivia',
            ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true, 'room_code' => 'TEST99']);

        // Join another player
        $joinResponse = $this->withHeader('X-Device-Id', 'device-player-2')
            ->postJson('/api/v1/rooms/TEST99/join');

        $joinResponse->assertStatus(200)
            ->assertJson(['success' => true]);

        $session = RoomSession::where('room_code', 'TEST99')->first();
        $this->assertNotNull($session);
        $this->assertContains('device-host-1', $session->activeDeviceIds());
        $this->assertContains('device-player-2', $session->activeDeviceIds());
    }

    public function test_next_question_excludes_items_seen_by_any_attendee(): void
    {
        $category = Category::first();

        $q1 = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رقم 1 القديم؟',
            'options' => ['أ', 'ب', 'ج', 'د'],
            'correct_index' => 0,
            'difficulty' => 'medium',
            'source' => 'seed',
            'content_hash' => 'hash_q1',
            'status' => 'active',
            'is_active' => true,
        ]);

        $q2 = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رقم 2 الجديد الذي لم يره أحد؟',
            'options' => ['س', 'ص', 'ع', 'ف'],
            'correct_index' => 1,
            'difficulty' => 'medium',
            'source' => 'seed',
            'content_hash' => 'hash_q2',
            'status' => 'active',
            'is_active' => true,
        ]);

        // Device 2 already saw q1
        DeviceContentHistory::markSeen(['device-player-2'], 'trivia', $q1->id);

        $this->withHeader('X-Device-Id', 'device-host-1')
            ->postJson('/api/v1/rooms', ['room_code' => 'ROOM1']);

        $this->withHeader('X-Device-Id', 'device-player-2')
            ->postJson('/api/v1/rooms/ROOM1/join');

        // Request next question for the room
        $response = $this->withHeader('X-Device-Id', 'device-host-1')
            ->getJson('/api/v1/rooms/ROOM1/next-question');

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        // Must NOT be q1 because player 2 already saw it!
        $this->assertEquals($q2->id, $response->json('data.id'));

        // Correct index must NEVER be leaked in the response!
        $this->assertArrayNotHasKey('correct_index', $response->json('data'));
        $this->assertArrayHasKey('salted_hash', $response->json('data'));

        // Both devices must now have q2 marked as seen
        $this->assertTrue(DeviceContentHistory::where('device_id', 'device-host-1')->where('content_id', $q2->id)->exists());
        $this->assertTrue(DeviceContentHistory::where('device_id', 'device-player-2')->where('content_id', $q2->id)->exists());
    }

    public function test_grade_question_validates_and_reveals_correct_index(): void
    {
        $category = Category::first();
        $q = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال الاختبار؟',
            'options' => ['خيار 0', 'خيار 1', 'خيار 2', 'خيار 3'],
            'correct_index' => 2,
            'difficulty' => 'medium',
            'source' => 'seed',
            'content_hash' => 'hash_q_grade',
            'status' => 'active',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/v1/rooms/ROOM1/grade-question', [
            'question_id' => $q->id,
            'chosen_index' => 2,
            'time_remaining' => 10,
            'total_seconds' => 15,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_correct' => true,
                'correct_index' => 2,
            ]);

        $this->assertGreaterThan(100, $response->json('points_earned'));
    }

    public function test_next_spy_round_returns_homogeneous_choices(): void
    {
        $this->withHeader('X-Device-Id', 'device-host-1')
            ->postJson('/api/v1/rooms', ['room_code' => 'SPYROOM']);

        $response = $this->withHeader('X-Device-Id', 'device-host-1')
            ->getJson('/api/v1/rooms/SPYROOM/next-spy-round?pack=places');

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $data = $response->json('data');
        $this->assertNotEmpty($data['secret_word']);
        $this->assertCount(4, $data['spy_choices']);

        // All 4 spy choices must belong to the same group!
        $groupWords = SpyGroupWord::where('group_id', $data['group_id'])->pluck('word_ar')->all();
        foreach ($data['spy_choices'] as $choice) {
            $this->assertContains($choice, $groupWords);
        }
    }

    public function test_two_reports_automatically_quarantine_question(): void
    {
        $category = Category::first();
        $q = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال يحتوي على معلومة خاطئة؟',
            'options' => ['أ', 'ب', 'ج', 'د'],
            'correct_index' => 0,
            'difficulty' => 'medium',
            'source' => 'seed',
            'content_hash' => 'hash_report_test',
            'status' => 'active',
            'is_active' => true,
        ]);

        // First report
        $res1 = $this->withHeader('X-Device-Id', 'user-1')
            ->postJson('/api/v1/content/report', [
                'content_type' => 'trivia',
                'content_id' => $q->id,
                'reason' => 'إجابة غير دقيقة',
            ]);
        $res1->assertJson(['success' => true, 'quarantined' => false]);
        $this->assertEquals('active', $q->fresh()->status);

        // Second report triggers quarantine
        $res2 = $this->withHeader('X-Device-Id', 'user-2')
            ->postJson('/api/v1/content/report', [
                'content_type' => 'trivia',
                'content_id' => $q->id,
                'reason' => 'محتوى غير صحيح',
            ]);
        $res2->assertJson(['success' => true, 'quarantined' => true]);
        $this->assertEquals('quarantined', $q->fresh()->status);
        $this->assertFalse($q->fresh()->is_active);
    }
}
