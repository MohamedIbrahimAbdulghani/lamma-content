<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GenerateContentApiRequest;
use App\Http\Resources\AiContentResource;
use App\Services\GenerateAiContentService;
use Illuminate\Http\JsonResponse;

class ContentGenerationController extends Controller
{
    public function __construct(
        private readonly GenerateAiContentService $aiContentService
    ) {}

    public function generate(GenerateContentApiRequest $request): JsonResponse
    {
        $gameType = (string) $request->validated('game_type');
        $category = $request->validated('category');
        $categories = (array) ($request->validated('categories') ?? []);
        $difficulty = $request->validated('difficulty');
        $count = (int) ($request->validated('count') ?? 20);
        $excludeItems = (array) ($request->validated('exclude_items') ?? []);

        // هنا بنطلب توليد المحتوى من خدمة الذكاء الاصطناعي مع تمرير الإعدادات المحددة
        $items = $this->aiContentService->generate(
            gameType: $gameType,
            category: $category,
            count: $count,
            excludeItems: $excludeItems,
            difficulty: $difficulty,
            categories: $categories,
        );

        return response()->json([
            'success' => true,
            'game_type' => $gameType,
            'count' => count($items),
            'data' => AiContentResource::collection($items),
        ]);
    }
}

