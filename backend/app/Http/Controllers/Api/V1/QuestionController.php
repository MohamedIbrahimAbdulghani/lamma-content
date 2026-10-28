<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GetQuestionsRequest;
use App\Http\Requests\Api\GetStockRequest;
use App\Http\Requests\Api\MarkSeenQuestionsRequest;
use App\Http\Resources\QuestionResource;
use App\Models\Category;
use App\Models\Question;
use App\Models\SeenQuestion;
use Illuminate\Http\JsonResponse;

class QuestionController extends Controller
{
    public function index(GetQuestionsRequest $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id');
        $count = (int) $request->input('count', 10);
        $difficulty = $request->input('difficulty');
        $categoriesParam = $request->input('categories');

        $seenIds = SeenQuestion::where('device_id', $deviceId)->pluck('question_id')->all();

        $query = Question::with('category')
            ->where('is_active', true)
            ->whereNotIn('id', $seenIds);

        if (!empty($categoriesParam)) {
            $slugs = array_filter(array_map('trim', explode(',', $categoriesParam)));
            if (!empty($slugs)) {
                $query->whereHas('category', fn ($q) => $q->whereIn('slug', $slugs));
            }
        }

        if (!empty($difficulty) && $difficulty !== 'mixed') {
            $query->where('difficulty', $difficulty);
        }

        $totalAvailable = (clone $query)->count();
        $questions = $query->inRandomOrder()->limit($count)->get();
        $isExhausted = $totalAvailable < $count;

        return response()->json([
            'data' => QuestionResource::collection($questions),
            'exhausted' => $isExhausted,
            'available' => $totalAvailable,
        ]);
    }

    public function markSeen(MarkSeenQuestionsRequest $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id');
        $questionIds = (array) $request->input('question_ids', []);

        $records = [];
        $now = now();
        foreach ($questionIds as $qid) {
            $records[] = [
                'device_id' => $deviceId,
                'question_id' => $qid,
                'seen_at' => $now,
            ];
        }

        if (!empty($records)) {
            SeenQuestion::insertOrIgnore($records);
        }

        return response()->json([
            'success' => true,
            'recorded' => count($questionIds),
        ]);
    }

    public function stock(GetStockRequest $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id');
        $categoriesParam = $request->input('categories');

        $seenIds = SeenQuestion::where('device_id', $deviceId)->pluck('question_id')->all();

        $categoriesQuery = Category::where('is_active', true)->where('kind', 'trivia');
        if (!empty($categoriesParam)) {
            $slugs = array_filter(array_map('trim', explode(',', $categoriesParam)));
            if (!empty($slugs)) {
                $categoriesQuery->whereIn('slug', $slugs);
            }
        }
        $categories = $categoriesQuery->get();

        $stock = [];
        $totalUnseen = 0;

        foreach ($categories as $cat) {
            $unseenCount = Question::where('category_id', $cat->id)
                ->where('is_active', true)
                ->whereNotIn('id', $seenIds)
                ->count();
            $stock[$cat->slug] = $unseenCount;
            $totalUnseen += $unseenCount;
        }

        return response()->json([
            'stock' => $stock,
            'total_unseen' => $totalUnseen,
        ]);
    }
}
