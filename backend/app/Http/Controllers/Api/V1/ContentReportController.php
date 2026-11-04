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

        // عدد الأجهزة الفريدة المختلفة التي أبلغت عن هذا العنصر
        $distinctDevices = ContentReport::where('content_type', $contentType)
            ->where('content_id', $contentId)
            ->distinct('device_id')
            ->count('device_id');

        $quarantined = false;

        if ($contentType === 'trivia') {
            $item = Question::find($contentId);
            if ($item) {
                $item->reports_count = $distinctDevices;
                if ($distinctDevices >= 2) {
                    $item->status = 'quarantined';
                    $item->is_active = false;
                    $item->rejection_reason = 'تم العزل تلقائياً بعد تلقي بلاغات من جهازين مختلفين عن خطأ في السؤال/الإجابة';
                    $quarantined = true;
                }
                $item->save();
            }
        } elseif ($contentType === 'spy_group') {
            $item = SpyWordGroup::find($contentId);
            if ($item) {
                $item->reports_count = $distinctDevices;
                if ($distinctDevices >= 2) {
                    $item->status = 'quarantined';
                    $quarantined = true;
                }
                $item->save();
            }
        } elseif ($contentType === 'charades') {
            $item = CharadesWord::find($contentId);
            if ($item) {
                $item->reports_count = $distinctDevices;
                if ($distinctDevices >= 2) {
                    $item->status = 'quarantined';
                    $item->is_active = false;
                    $quarantined = true;
                }
                $item->save();
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'تم استلام البلاغ بنجاح',
            'quarantined' => $quarantined,
        ]);
    }
}
