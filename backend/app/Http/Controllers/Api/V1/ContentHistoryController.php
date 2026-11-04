<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DeviceContentHistory;
use App\Models\SeenQuestion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentHistoryController extends Controller
{
    public function reset(Request $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id');

        if (!empty($deviceId)) {
            SeenQuestion::where('device_id', $deviceId)->delete();
            DeviceContentHistory::where('device_id', $deviceId)->delete();
        }

        return response()->json([
            'success' => true,
            'message' => 'تم إعادة ضبط سجل الأسئلة بنجاح',
        ]);
    }
}

