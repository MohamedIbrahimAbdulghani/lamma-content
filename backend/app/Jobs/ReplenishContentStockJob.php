<?php
// Lamma - by Mohamed Ibrahim

namespace App\Jobs;

use App\Models\Category;
use App\Models\Question;
use App\Models\SpyWordGroup;
use App\Services\AutonomousContentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ReplenishContentStockJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 2;
    public int $timeout = 60;

    protected string $type; // 'trivia', 'spy', 'all'
    protected ?string $categorySlug;
    protected string $difficulty;

    public function __construct(string $type = 'trivia', ?string $categorySlug = null, string $difficulty = 'medium')
    {
        $this->type = $type;
        $this->categorySlug = $categorySlug;
        $this->difficulty = $difficulty;
    }

    public function handle(AutonomousContentService $service): void
    {
        Log::info("ReplenishContentStockJob started for type: {$this->type}, category: {$this->categorySlug}");

        if ($this->type === 'trivia' || $this->type === 'all') {
            $categories = $this->categorySlug
                ? Category::where('slug', $this->categorySlug)->get()
                : Category::where('is_active', true)->get();

            foreach ($categories as $cat) {
                $activeCount = Question::where('category_id', $cat->id)
                    ->where('status', 'active')
                    ->where('difficulty', $this->difficulty)
                    ->count();

                // إذا انخفض المخزون عن 15 سؤالاً، يتم التوليد التلقائي لدفعة من 8 أسئلة
                if ($activeCount < 15) {
                    $result = $service->generateTriviaQuestions($cat->slug, $this->difficulty, 8);
                    Log::info("Replenished trivia for category [{$cat->slug}]: approved {$result['approved']}, rejected {$result['rejected']}");
                }
            }
        }

        if ($this->type === 'spy' || $this->type === 'all') {
            $packs = ['places', 'movies', 'foods', 'mixed'];
            foreach ($packs as $pack) {
                $groupsCount = SpyWordGroup::where('pack_slug', $pack)
                    ->where('status', 'active')
                    ->count();

                // الحفاظ على 8 مجموعات على الأقل لكل حزمة
                if ($groupsCount < 8) {
                    $res = $service->generateSpyWordGroup($pack, $this->difficulty);
                    Log::info("Replenished spy group for pack [{$pack}]: " . json_encode($res));
                }
            }
        }
    }
}
