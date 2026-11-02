<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GenerateAiContentService;
use Illuminate\Http\JsonResponse;

class HealthController extends Controller
{
    public function health(): JsonResponse
    {
        return response()->json([
            'status' => 'ok',
            'app' => 'Lamma',
            'developer' => 'Mohamed Ibrahim',
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    public function aiHealth(GenerateAiContentService $aiService): JsonResponse
    {
        $health = $aiService->checkHealth();
        $statusCode = $health['healthy'] ? 200 : 503;

        return response()->json($health, $statusCode);
    }
}
