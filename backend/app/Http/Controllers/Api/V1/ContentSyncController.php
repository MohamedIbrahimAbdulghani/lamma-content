<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CharadesWord;
use App\Models\DeviceContentHistory;
use App\Models\Question;
use App\Models\SpyWordGroup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentSyncController extends Controller
{
    /**
     * استعلام آمن تماماً عن حالة المحتوى دون كشف أو معاينة أي أسئلة
     */
    public function syncStatus(Request $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id', '');

        $totalActiveQuestions = Question::where('status', 'active')->where('is_active', true)->count();
        $totalActiveSpyGroups = SpyWordGroup::where('status', 'active')->count();
        $totalActiveCharades = CharadesWord::where('status', 'active')->where('is_active', true)->count();

        $seenQuestionsCount = 0;
        if (!empty($deviceId)) {
            $seenQuestionsCount = DeviceContentHistory::where('device_id', $deviceId)
                ->where('content_type', 'trivia')
                ->count();
        }

        $freshQuestionsAvailable = max(0, $totalActiveQuestions - $seenQuestionsCount);

        return response()->json([
            'success' => true,
            'data' => [
                'total_questions' => $totalActiveQuestions,
                'fresh_questions_available' => $freshQuestionsAvailable,
                'spy_groups_available' => $totalActiveSpyGroups,
                'charades_words_available' => $totalActiveCharades,
                'is_synchronized' => true,
                'last_updated' => now()->toIso8601String(),
            ],
        ]);
    }

    /**
     * رفع ومزامنة سجل المشاهدات من الموبايل إلى الباك إند
     */
    public function syncHistory(Request $request): JsonResponse
    {
        $deviceId = (string) $request->header('X-Device-Id', $request->input('device_id', ''));
        if (empty($deviceId)) {
            return response()->json(['success' => false, 'error' => 'Device ID required'], 422);
        }

        $triviaIds = (array) $request->input('seen_trivia_ids', []);
        $spyGroupIds = (array) $request->input('seen_spy_group_ids', []);
        $charadesIds = (array) $request->input('seen_charades_ids', []);

        $synced = 0;
        foreach ($triviaIds as $id) {
            DeviceContentHistory::markSeen([$deviceId], 'trivia', (int) $id);
            $synced++;
        }
        foreach ($spyGroupIds as $id) {
            DeviceContentHistory::markSeen([$deviceId], 'spy_group', (int) $id);
            $synced++;
        }
        foreach ($charadesIds as $id) {
            DeviceContentHistory::markSeen([$deviceId], 'charades', (int) $id);
            $synced++;
        }

        return response()->json([
            'success' => true,
            'synced_count' => $synced,
        ]);
    }
}
