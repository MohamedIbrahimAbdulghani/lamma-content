<?php
// Lamma - by Mohamed Ibrahim

namespace Tests\Feature;

use App\Models\Avatar;
use App\Models\Category;
use App\Models\CharadesCategory;
use App\Models\CharadesWord;
use App\Models\ContentVersion;
use App\Models\Question;
use App\Models\RulePage;
use App\Models\SeenQuestion;
use App\Models\SpyWord;
use App\Models\SpyWordPack;
use Database\Seeders\AppSettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LammaApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(AppSettingSeeder::class);
        ContentVersion::create(['version' => 1, 'generated_at' => now(), 'notes' => 'Test']);
    }

    public function test_health_check_returns_ok(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'ok',
                'app' => 'Lamma',
                'developer' => 'Mohamed Ibrahim',
            ]);
    }

    public function test_bootstrap_returns_correct_shape(): void
    {
        $category = Category::create([
            'slug' => 'afeehat',
            'name_ar' => 'أفيهات',
            'emoji' => '😂',
            'kind' => 'trivia',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $pack = SpyWordPack::create(['slug' => 'places', 'name_ar' => 'أماكن']);
        SpyWord::create([
            'pack_id' => $pack->id,
            'word_ar' => 'الأهرامات',
            'content_hash' => SpyWord::makeContentHash('الأهرامات'),
            'is_active' => true,
            'source' => 'seed',
        ]);

        $charadesCat = CharadesCategory::create(['slug' => 'movies', 'name_ar' => 'أفلام']);
        CharadesWord::create([
            'category_id' => $charadesCat->id,
            'word_ar' => 'الكيف',
            'content_hash' => CharadesWord::makeContentHash('الكيف'),
            'is_active' => true,
            'source' => 'seed',
        ]);

        Avatar::create(['emoji' => '🦁', 'name_ar' => 'أسد', 'sort_order' => 1]);

        RulePage::create([
            'slug' => 'app_guide',
            'title_ar' => 'دليل التطبيق',
            'accent' => 'saffron',
            'sections' => [['heading' => 'البداية', 'kind' => 'text', 'items' => ['مرحبا']]],
        ]);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'version',
                'last_updated',
                'categories' => [['id', 'slug', 'name_ar', 'emoji', 'kind', 'is_active', 'sort_order']],
                'spy' => ['packs' => [['id', 'slug', 'name_ar', 'words']]],
                'charades' => ['categories' => [['id', 'slug', 'name_ar', 'words']]],
                'avatars' => [['id', 'emoji', 'name_ar', 'sort_order']],
                'rule_pages' => [['id', 'slug', 'title_ar', 'accent', 'sections']],
                'settings' => ['spy', 'trivia', 'charades', 'scoring', 'anti_cheat'],
            ]);
    }

    public function test_validation_errors_when_x_device_id_missing(): void
    {
        $response = $this->getJson('/api/v1/questions');
        $response->assertStatus(422)
            ->assertJsonStructure(['error', 'messages' => ['x_device_id']]);

        $responseSeen = $this->postJson('/api/v1/questions/seen', ['question_ids' => [1]]);
        $responseSeen->assertStatus(422);

        $responseStock = $this->getJson('/api/v1/questions/stock');
        $responseStock->assertStatus(422);
    }

    public function test_validation_errors_for_invalid_parameters(): void
    {
        $response = $this->withHeader('X-Device-Id', 'dev-1')
            ->getJson('/api/v1/questions?difficulty=super_hard');
        $response->assertStatus(422);

        $response2 = $this->withHeader('X-Device-Id', 'dev-1')
            ->getJson('/api/v1/questions?count=999');
        $response2->assertStatus(422);
    }

    public function test_no_repeats_across_calls_for_same_device(): void
    {
        $category = Category::create([
            'slug' => 'afeehat',
            'name_ar' => 'أفيهات',
            'emoji' => '😂',
            'kind' => 'trivia',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $q1 = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رقم 1',
            'options' => ['أ', 'ب', 'ج', 'د'],
            'correct_index' => 0,
            'difficulty' => 'easy',
            'source' => 'seed',
            'content_hash' => Question::makeContentHash('سؤال رقم 1'),
            'is_active' => true,
            'published_at' => now(),
        ]);

        $q2 = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال رقم 2',
            'options' => ['أ', 'ب', 'ج', 'د'],
            'correct_index' => 1,
            'difficulty' => 'easy',
            'source' => 'seed',
            'content_hash' => Question::makeContentHash('سؤال رقم 2'),
            'is_active' => true,
            'published_at' => now(),
        ]);

        // Device 1 gets 1 question
        $res1 = $this->withHeader('X-Device-Id', 'device-A')
            ->getJson('/api/v1/questions?count=1');
        $res1->assertStatus(200);
        $retrievedId = $res1->json('data.0.id');

        // Mark it seen
        $this->withHeader('X-Device-Id', 'device-A')
            ->postJson('/api/v1/questions/seen', ['question_ids' => [$retrievedId]])
            ->assertStatus(200);

        // Next call should NOT return the seen question
        $res2 = $this->withHeader('X-Device-Id', 'device-A')
            ->getJson('/api/v1/questions?count=1');
        $res2->assertStatus(200);
        $nextId = $res2->json('data.0.id');

        $this->assertNotEquals($retrievedId, $nextId);
    }

    public function test_different_devices_are_independent(): void
    {
        $category = Category::create([
            'slug' => 'kora',
            'name_ar' => 'كورة',
            'emoji' => '⚽',
            'kind' => 'trivia',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $q = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال الكورة',
            'options' => ['الأهلي', 'الزمالك', 'الإسماعيلي', 'بيراميدز'],
            'correct_index' => 0,
            'difficulty' => 'easy',
            'source' => 'seed',
            'content_hash' => Question::makeContentHash('سؤال الكورة'),
            'is_active' => true,
            'published_at' => now(),
        ]);

        // Device 1 marks it seen
        SeenQuestion::create([
            'device_id' => 'device-1',
            'question_id' => $q->id,
            'seen_at' => now(),
        ]);

        // Device 1 sees 0 available
        $res1 = $this->withHeader('X-Device-Id', 'device-1')
            ->getJson('/api/v1/questions?count=5');
        $res1->assertStatus(200)
            ->assertJson([
                'exhausted' => true,
                'available' => 0,
            ]);
        $this->assertCount(0, $res1->json('data'));

        // Device 2 is fresh and still sees the question
        $res2 = $this->withHeader('X-Device-Id', 'device-2')
            ->getJson('/api/v1/questions?count=5');
        $res2->assertStatus(200)
            ->assertJson([
                'available' => 1,
            ]);
        $this->assertCount(1, $res2->json('data'));
        $this->assertEquals($q->id, $res2->json('data.0.id'));
    }

    public function test_exhausted_flag_works_when_fewer_questions_available(): void
    {
        $category = Category::create([
            'slug' => 'general',
            'name_ar' => 'عام',
            'emoji' => '🧠',
            'kind' => 'trivia',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال وحيد',
            'options' => ['1', '2', '3', '4'],
            'correct_index' => 0,
            'difficulty' => 'easy',
            'source' => 'seed',
            'content_hash' => Question::makeContentHash('سؤال وحيد'),
            'is_active' => true,
            'published_at' => now(),
        ]);

        // Request 5 questions when only 1 exists
        $response = $this->withHeader('X-Device-Id', 'dev-test')
            ->getJson('/api/v1/questions?count=5');

        $response->assertStatus(200)
            ->assertJson([
                'exhausted' => true,
                'available' => 1,
            ]);
        $this->assertCount(1, $response->json('data'));
    }

    public function test_stock_endpoint_counts_unseen_questions(): void
    {
        $category = Category::create([
            'slug' => 'nokat',
            'name_ar' => 'نكت',
            'emoji' => '😄',
            'kind' => 'trivia',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $q = Question::create([
            'category_id' => $category->id,
            'type' => 'mcq',
            'prompt_ar' => 'سؤال نكتة',
            'options' => ['أ', 'ب', 'ج', 'د'],
            'correct_index' => 0,
            'difficulty' => 'easy',
            'source' => 'seed',
            'content_hash' => Question::makeContentHash('سؤال نكتة'),
            'is_active' => true,
            'published_at' => now(),
        ]);

        // Stock before seeing
        $stock1 = $this->withHeader('X-Device-Id', 'dev-stock')
            ->getJson('/api/v1/questions/stock');
        $stock1->assertStatus(200)
            ->assertJson([
                'stock' => ['nokat' => 1],
                'total_unseen' => 1,
            ]);

        // Mark seen
        SeenQuestion::create([
            'device_id' => 'dev-stock',
            'question_id' => $q->id,
            'seen_at' => now(),
        ]);

        // Stock after seeing
        $stock2 = $this->withHeader('X-Device-Id', 'dev-stock')
            ->getJson('/api/v1/questions/stock');
        $stock2->assertStatus(200)
            ->assertJson([
                'stock' => ['nokat' => 0],
                'total_unseen' => 0,
            ]);
    }
}
