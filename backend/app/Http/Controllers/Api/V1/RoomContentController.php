<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Helpers\ArabicNormalizer;
use App\Http\Controllers\Controller;
use App\Jobs\ReplenishContentStockJob;
use App\Models\CharadesWord;
use App\Models\DeviceContentHistory;
use App\Models\Question;
use App\Models\RoomSession;
use App\Models\RoomSessionDevice;
use App\Models\SpyWordGroup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RoomContentController extends Controller
{
    /**
     * تسجيل جلسة غرفة جديدة على الباك إند
     */
    public function createRoom(Request $request): JsonResponse
    {
        $roomCode = strtoupper(trim((string) $request->input('room_code', '')));
        $deviceId = (string) $request->header('X-Device-Id', $request->input('device_id', ''));
        $gameMode = (string) $request->input('game_mode', 'trivia');

        if (empty($roomCode)) {
            return response()->json(['success' => false, 'error' => 'كود الغرفة مطلوب'], 422);
        }

        $session = RoomSession::updateOrCreate(
            ['room_code' => $roomCode],
            [
                'host_device_id' => $deviceId,
                'status' => 'lobby',
                'current_game' => $gameMode,
            ]
        );

        if (!empty($deviceId)) {
            RoomSessionDevice::updateOrCreate(
                ['room_session_id' => $session->id, 'device_id' => $deviceId],
                ['joined_at' => now(), 'left_at' => null]
            );
        }

        return response()->json([
            'success' => true,
            'room_code' => $roomCode,
            'session_id' => $session->id,
            'devices_count' => count($session->activeDeviceIds()),
        ]);
    }

    /**
     * تسجيل انضمام جهاز للغرفة
     */
    public function joinRoom(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $deviceId = (string) $request->header('X-Device-Id', $request->input('device_id', ''));

        $session = RoomSession::where('room_code', $roomCode)->first();
        if (!$session) {
            $session = RoomSession::create([
                'room_code' => $roomCode,
                'host_device_id' => $deviceId,
                'status' => 'active',
            ]);
        }

        if (!empty($deviceId)) {
            RoomSessionDevice::updateOrCreate(
                ['room_session_id' => $session->id, 'device_id' => $deviceId],
                ['joined_at' => now(), 'left_at' => null]
            );
        }

        return response()->json([
            'success' => true,
            'room_code' => $roomCode,
            'active_devices' => $session->activeDeviceIds(),
        ]);
    }

    /**
     * تسجيل مغادرة جهاز من الغرفة
     */
    public function leaveRoom(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $deviceId = (string) $request->header('X-Device-Id', $request->input('device_id', ''));

        $session = RoomSession::where('room_code', $roomCode)->first();
        if ($session && !empty($deviceId)) {
            RoomSessionDevice::where('room_session_id', $session->id)
                ->where('device_id', $deviceId)
                ->update(['left_at' => now()]);
        }

        return response()->json(['success' => true]);
    }

    /**
     * جلب السؤال التالي لتحدي الشلة:
     * - يستبعد ما شاهده أي جهاز حاضر في الغرفة
     * - يُسجل فوراً كمشاهد لجميع الحاضرين
     * - يُرسل السؤال والاختيارات فقط بدون الإجابة الصحيحة
     */
    public function getNextQuestion(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $categoriesParam = $request->input('categories');
        $difficulty = $request->input('difficulty');

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        // 1. جمع معرّفات الأسئلة التي شاهدها أي جهاز حاضر
        $seenIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'trivia')
            ->pluck('content_id')
            ->all();

        // 2. بناء الاستعلام
        $query = Question::with('category')
            ->where('status', 'active')
            ->where('is_active', true);

        if (!empty($categoriesParam)) {
            $slugs = array_filter(array_map('trim', explode(',', $categoriesParam)));
            if (!empty($slugs) && !in_array('all', $slugs, true)) {
                $query->whereHas('category', fn ($q) => $q->whereIn('slug', $slugs));
            }
        }

        if (!empty($difficulty) && $difficulty !== 'all' && $difficulty !== 'mixed') {
            $query->where('difficulty', $difficulty);
        }

        // محاولة جلب سؤال لم يشاهده أحد
        $question = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->first();

        // إذا نفد المخزون غير المشاهد، يتم أخذ الأقدم مشاهدة بنظام تدوير محكم
        if (!$question) {
            $question = (clone $query)->inRandomOrder()->first();
        }

        if (!$question) {
            return response()->json(['success' => false, 'error' => 'لا توجد أسئلة متاحة في هذا القسم حالياً'], 404);
        }

        // 3. تسجيل السؤال فوراً كمشاهد لجميع الحاضرين
        if (!empty($deviceIds)) {
            DeviceContentHistory::markSeen($deviceIds, 'trivia', $question->id);
        }
        $question->increment('times_served');

        // 4. تشغيل وظيفة التعويض التلقائي في الخلفية إذا قل المخزون
        ReplenishContentStockJob::dispatch('trivia', $question->category?->slug, $question->difficulty)->afterResponse();

        // 5. التشفير والتأمين: الإجابة الصحيحة لا تُرسل مكشوفة أبداً
        $saltedHash = ArabicNormalizer::saltedAnswerHash(
            $question->id,
            $question->options[$question->correct_index] ?? ''
        );

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $question->id,
                'category_id' => $question->category_id,
                'category_slug' => $question->category?->slug ?? 'general',
                'prompt_ar' => $question->prompt_ar,
                'emoji_prompt' => $question->emoji_prompt,
                'options' => $question->options,
                'difficulty' => $question->difficulty,
                'points' => 100,
                // تجزئة مملحة للتحقق الأوفلاين السري دون كشف رقم الإجابة
                'salted_hash' => $saltedHash,
            ],
        ]);
    }

    /**
     * تصحيح الإجابة من جهة الخادم وحساب النتيجة
     */
    public function gradeQuestion(Request $request, string $roomCode): JsonResponse
    {
        $questionId = (int) $request->input('question_id');
        $chosenIndex = (int) $request->input('chosen_index', -1);
        $timeRemaining = (int) $request->input('time_remaining', 0);
        $totalSeconds = (int) $request->input('total_seconds', 15);

        $question = Question::find($questionId);
        if (!$question) {
            return response()->json(['success' => false, 'error' => 'السؤال غير موجود'], 404);
        }

        $isCorrect = ($chosenIndex === $question->correct_index);

        // احتساب النقاط مع بونص السرعة
        $points = 0;
        if ($isCorrect) {
            $basePoints = 100;
            $speedBonus = ($totalSeconds > 0) ? (int) round(($timeRemaining / $totalSeconds) * 50) : 0;
            $points = $basePoints + $speedBonus;
        }

        return response()->json([
            'success' => true,
            'is_correct' => $isCorrect,
            'correct_index' => $question->correct_index,
            'explanation_ar' => $question->explanation_ar,
            'points_earned' => $points,
        ]);
    }

    /**
     * جلب الجولة التالية للعبة مين الجاسوس:
     * - مجموعة متجانسة لم يشاهدها أحد
     * - كلمة سرية
     * - 4 اختيارات متجانسة تماماً من نفس المجموعة لشاشة الفرصة الأخيرة للجاسوس
     */
    public function getNextSpyRound(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $packSlug = (string) $request->input('pack', 'places');
        $difficulty = (string) $request->input('difficulty', 'medium');

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        $seenGroupIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'spy_group')
            ->pluck('content_id')
            ->all();

        $query = SpyWordGroup::with('words')
            ->where('status', 'active');

        if (!empty($packSlug) && $packSlug !== 'mixed') {
            $query->where('pack_slug', $packSlug);
        }

        if (!empty($difficulty) && $difficulty !== 'mixed' && $difficulty !== 'all') {
            $query->where('difficulty', $difficulty);
        }

        $group = (clone $query)->whereNotIn('id', $seenGroupIds)->inRandomOrder()->first();
        if (!$group) {
            $group = (clone $query)->inRandomOrder()->first();
        }

        if (!$group || $group->words->count() < 4) {
            // الرجوع لأي مجموعة نشطة صالحة
            $group = SpyWordGroup::with('words')->where('status', 'active')->has('words', '>=', 4)->inRandomOrder()->first();
        }

        if (!$group) {
            return response()->json(['success' => false, 'error' => 'لا توجد مجموعات كلمات متاحة'], 404);
        }

        // تسجيل المجموعة كمشاهدة لجميع الحاضرين
        if (!empty($deviceIds)) {
            DeviceContentHistory::markSeen($deviceIds, 'spy_group', $group->id);
        }
        $group->increment('times_served');

        // تعويض المخزون تلقائياً في الخلفية
        ReplenishContentStockJob::dispatch('spy', $packSlug, $difficulty)->afterResponse();

        $allWords = $group->words->pluck('word_ar')->all();
        shuffle($allWords);

        // اختيار الكلمة السرية
        $secretWord = $allWords[0];

        // اختيار 3 بدائل متجانسة جداً من نفس المجموعة
        $distractors = array_slice($allWords, 1, 3);
        $spyChoices = array_merge([$secretWord], $distractors);
        shuffle($spyChoices);

        return response()->json([
            'success' => true,
            'data' => [
                'group_id' => $group->id,
                'pack_slug' => $group->pack_slug,
                'group_title_ar' => $group->title_ar,
                'theme' => $group->theme,
                'difficulty' => $group->difficulty,
                'secret_word' => $secretWord,
                // قائمة الفرصة الأخيرة للجاسوس: 4 عناصر متجانسة من نفس المستوى تماماً
                'spy_choices' => $spyChoices,
            ],
        ]);
    }

    /**
     * جلب الكلمة التالية للعبة مثّل ومتتكلمش
     */
    public function getNextCharades(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $categorySlug = (string) $request->input('category', 'movies');

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        $seenIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'charades')
            ->pluck('content_id')
            ->all();

        $query = CharadesWord::where('status', 'active')->where('is_active', true);
        if (!empty($categorySlug) && $categorySlug !== 'mixed') {
            $query->whereHas('category', fn ($q) => $q->where('slug', $categorySlug));
        }

        $word = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->first();
        if (!$word) {
            $word = (clone $query)->inRandomOrder()->first();
        }

        if (!$word) {
            return response()->json(['success' => false, 'error' => 'لا توجد كلمات متاحة'], 404);
        }

        if (!empty($deviceIds)) {
            DeviceContentHistory::markSeen($deviceIds, 'charades', $word->id);
        }
        $word->increment('times_served');

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $word->id,
                'word_ar' => $word->word_ar,
            ],
        ]);
    }
}
