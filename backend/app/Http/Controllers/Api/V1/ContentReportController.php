<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CharadesWord;
use App\Models\ContentReport;
use App\Models\Question;
use App\Models\SpyWordGroup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentReportController extends Controller
{
    public function report(Request $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id', $request->input('device_id', 'anonymous'));
        $contentType = (string) $request->input('content_type', 'trivia');
        $contentId = (int) $request->input('content_id');
        $reason = (string) $request->input('reason', 'بلاغ من لاعب');

        if ($contentId <= 0) {
            return response()->json(['success' => false, 'error' => 'معرف المحتوى غير صالح'], 422);
        }

        // تسجيل البلاغ
        ContentReport::create([
            'device_id' => $deviceId,
            'content_type' => $contentType,
            'content_id' => $contentId,
            'reason' => $reason,
        ]);

        $quarantined = false;

        if ($contentType === 'trivia') {
            $item = Question::find($contentId);
            if ($item) {
                $item->increment('reports_count');
                if ($item->reports_count >= 2) {
                    $item->update(['status' => 'quarantined', 'is_active' => false]);
                    $quarantined = true;
                }
            }
        } elseif ($contentType === 'spy_group') {
            $item = SpyWordGroup::find($contentId);
            if ($item) {
                $item->increment('reports_count');
                if ($item->reports_count >= 2) {
                    $item->update(['status' => 'quarantined']);
                    $quarantined = true;
                }
            }
        } elseif ($contentType === 'charades') {
            $item = CharadesWord::find($contentId);
            if ($item) {
                $item->increment('reports_count');
                if ($item->reports_count >= 2) {
                    $item->update(['status' => 'quarantined', 'is_active' => false]);
                    $quarantined = true;
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'تم استلام البلاغ بنجاح',
            'quarantined' => $quarantined,
        ]);
    }
}
