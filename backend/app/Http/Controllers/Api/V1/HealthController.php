<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
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
}
