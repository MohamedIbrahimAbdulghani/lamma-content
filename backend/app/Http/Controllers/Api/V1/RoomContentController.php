<?php
// Lamma - by Mohamed Ibrahim

namespace App\Http\Controllers\Api\V1;

use App\Helpers\ArabicNormalizer;
use App\Http\Controllers\Controller;
use App\Jobs\ReplenishContentStockJob;
use App\Models\Category;
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
     * - يمنع تماماً أي تدوير صامت أو رجوع للأقدم مشاهدة
     * - يُرسل السؤال والاختيارات فقط بدون الإجابة الصحيحة
     */
    public function getNextQuestion(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $categoriesParam = $request->input('categories');
        $difficulty = $request->input('difficulty');
        $excludeHashes = (array) $request->input('exclude_hashes', []);

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

        // 2. بناء الاستعلام مع عزل الأسئلة المجمدة (quarantined)
        $query = Question::with('category')
            ->where('status', 'active')
            ->where('is_active', true);

        $resolvedSlugs = [];
        if (!empty($categoriesParam)) {
            $rawSlugs = array_filter(array_map('trim', explode(',', $categoriesParam)));
            if (!empty($rawSlugs) && !in_array('all', $rawSlugs, true)) {
                $resolvedSlugs = array_values(array_unique(array_map([Category::class, 'canonicalSlug'], $rawSlugs)));
                $query->whereHas('category', fn ($q) => $q->whereIn('slug', $resolvedSlugs));
            }
        }

        if (!empty($difficulty) && $difficulty !== 'all' && $difficulty !== 'mixed') {
            $query->where('difficulty', $difficulty);
        }

        $excludeAnswerHashes = (array) $request->input('exclude_answer_hashes', []);

        // جلب نصوص الأسئلة المشاهدة للتحقق من نسبة التشابه العالية (Jaccard >= 0.85)
        $seenPrompts = !empty($seenIds) ? Question::whereIn('id', $seenIds)->pluck('prompt_ar')->all() : [];

        // جلب الأسئلة المرشحة غير المشاهدة
        $candidates = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->limit(25)->get();

        $question = null;
        foreach ($candidates as $cand) {
            $pHash = ArabicNormalizer::promptHash($cand->prompt_ar . ' ' . ($cand->emoji_prompt ?? ''));
            if (in_array($pHash, $excludeHashes, true)) {
                continue;
            }

            // فحص بصمة الإجابة الصحيحة مع القسم
            $correctOption = $cand->options[$cand->correct_index] ?? '';
            $aHash = ArabicNormalizer::answerHash($cand->category?->slug ?? '', $correctOption);
            if (in_array($aHash, $excludeAnswerHashes, true)) {
                continue;
            }

            // فحص نسبة التشابه العالي مع أي سؤال سابق لنفس الأجهزة (Jaccard >= 0.85)
            $isTooSimilar = false;
            foreach ($seenPrompts as $seenP) {
                if (ArabicNormalizer::jaccardSimilarity($cand->prompt_ar, $seenP) >= 0.85) {
                    $isTooSimilar = true;
                    break;
                }
            }
            if ($isTooSimilar) {
                continue;
            }

            $question = $cand;
            break;
        }

        // ممنوع التدوير الصامت للأقدم مشاهدة
        if (!$question) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'نفد مخزون الأسئلة غير المشاهدة لهذا القسم بالكامل',
            ], 404);
        }

        // تأكيد نهائي صارم (Server-side Assertion) لمنع تسرب الأقسام
        $qSlug = Category::canonicalSlug($question->category?->slug ?? 'general');
        if (!empty($resolvedSlugs) && !in_array($qSlug, $resolvedSlugs, true)) {
            \Illuminate\Support\Facades\Log::critical("Category leak detected and blocked: Question {$question->id} ($qSlug) not in allowed: " . implode(',', $resolvedSlugs));
            return response()->json([
                'success' => false,
                'error' => 'category_mismatch',
                'message' => 'تم رصد تسرب قسم غير مصرح به وإسقاطه',
            ], 500);
        }

        // 3. تسجيل السؤال فوراً كمشاهد لجميع الحاضرين لحظة تقديمه
        if (!empty($deviceIds)) {
            DeviceContentHistory::markSeen($deviceIds, 'trivia', $question->id);
        }
        $question->increment('times_served');

        // 4. تشغيل وظيفة التعويض التلقائي في الخلفية
        ReplenishContentStockJob::dispatch('trivia', $qSlug, $question->difficulty)->afterResponse();

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
                'category_slug' => $qSlug,
                'prompt_ar' => $question->prompt_ar,
                'emoji_prompt' => $question->emoji_prompt,
                'options' => $question->options,
                'difficulty' => $question->difficulty,
                'points' => 100,
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
     * - الكلمة السرية لا تتكرر بين جولتين متتاليتين
     * - 4 اختيارات متجانسة تماماً من نفس المجموعة لشاشة الفرصة الأخيرة للجاسوس
     */
    public function getNextSpyRound(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $rawPack = (string) $request->input('pack', $request->input('pack_slug', 'places'));
        $packSlug = ($rawPack === 'food') ? 'foods' : $rawPack;
        $difficulty = (string) $request->input('difficulty', 'medium');
        $excludeWords = (array) $request->input('exclude_words', []);
        $prevWord = trim((string) $request->input('previous_word', ''));
        if (!empty($prevWord)) {
            $excludeWords[] = $prevWord;
        }

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

        if (!empty($packSlug) && !in_array($packSlug, ['mixed', 'all'], true)) {
            $query->where('pack_slug', $packSlug);
        }

        if (!empty($difficulty) && $difficulty !== 'mixed' && $difficulty !== 'all') {
            $query->where('difficulty', $difficulty);
        }

        $seenWordHashes = (array) $request->input('seen_word_hashes', []);

        $candidates = (clone $query)->whereNotIn('id', $seenGroupIds)->inRandomOrder()->get();

        $group = null;
        $secretWord = null;
        $allWords = [];

        foreach ($candidates as $cand) {
            if ($cand->words->count() < 4) continue;
            $words = $cand->words->pluck('word_ar')->all();
            shuffle($words);

            $candidateWords = array_values(array_filter($words, function ($w) use ($excludeWords, $seenWordHashes) {
                if (in_array($w, $excludeWords, true)) return false;
                $wHash = hash('sha256', ArabicNormalizer::normalize($w));
                if (in_array($wHash, $seenWordHashes, true)) return false;
                return true;
            }));

            if (!empty($candidateWords)) {
                $group = $cand;
                $secretWord = $candidateWords[0];
                $allWords = $words;
                break;
            }
        }

        // ممنوع التدوير الصامت
        if (!$group || empty($secretWord)) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'نفدت مجموعات الكلمات غير المشاهدة لهذه الحزمة بالكامل',
            ], 404);
        }

        // تأكيد نهائي صارم (Assertion) لمنع تسرب الحزم
        if (!empty($packSlug) && !in_array($packSlug, ['mixed', 'all'], true)) {
            if ($group->pack_slug !== $packSlug) {
                \Illuminate\Support\Facades\Log::critical("Spy pack leak blocked: {$group->pack_slug} != {$packSlug}");
                return response()->json([
                    'success' => false,
                    'error' => 'category_mismatch',
                    'message' => 'تم رصد تسرب حزمة غير مصرح بها وإسقاطها',
                ], 500);
            }
        }

        // تسجيل المجموعة كمشاهدة لجميع الحاضرين
        if (!empty($deviceIds)) {
            DeviceContentHistory::markSeen($deviceIds, 'spy_group', $group->id);
        }
        $group->increment('times_served');

        // تعويض المخزون تلقائياً في الخلفية
        ReplenishContentStockJob::dispatch('spy', $packSlug, $difficulty)->afterResponse();

        // إعداد خيارات الفرصة الأخيرة (4 كلمات متجانسة)
        $distractors = array_values(array_filter($allWords, fn($w) => $w !== $secretWord));
        shuffle($distractors);
        $spyChoices = array_merge([$secretWord], array_slice($distractors, 0, 3));
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
        $rawCat = (string) $request->input('category', 'movies');
        $canonicalCat = Category::canonicalSlug($rawCat);
        $excludeWords = (array) $request->input('exclude_words', []);

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        $seenIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'charades')
            ->pluck('content_id')
            ->all();

        $query = CharadesWord::with('category')->where('status', 'active')->where('is_active', true);
        if (!empty($canonicalCat) && !in_array($canonicalCat, ['mixed', 'all'], true)) {
            $query->whereHas('category', fn ($q) => $q->where('slug', $canonicalCat));
        }

        $candidates = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->limit(20)->get();

        $word = null;
        foreach ($candidates as $cand) {
            if (!in_array($cand->word_ar, $excludeWords, true)) {
                $word = $cand;
                break;
            }
        }

        // ممنوع التدوير الصامت عند النفاد
        if (!$word) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'نفدت كلمات التمثيل غير المشاهدة لهذا القسم بالكامل',
            ], 404);
        }

        // تأكيد نهائي صارم (Assertion) لمنع تسرب أقسام التمثيل
        if (!empty($canonicalCat) && !in_array($canonicalCat, ['mixed', 'all'], true)) {
            $wSlug = Category::canonicalSlug($word->category?->slug ?? '');
            if ($wSlug !== $canonicalCat) {
                \Illuminate\Support\Facades\Log::critical("Charades category leak blocked: {$wSlug} != {$canonicalCat}");
                return response()->json([
                    'success' => false,
                    'error' => 'category_mismatch',
                    'message' => 'تم رصد تسرب قسم غير مصرح به وإسقاطه',
                ], 500);
            }
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

    /**
     * جلب دفعة كاملة لتحدي الشلة مسبقاً للغرفة (Pre-buffering):
     * - يوزع الأسئلة بتوازن بين الأقسام المختارة
     * - يمنع تماماً أي سؤال خارج الأقسام المختارة
     */
    public function getNextQuestionsBatch(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $count = (int) min(30, max(1, $request->input('count', 10)));
        $categoriesParam = $request->input('categories');
        $difficulty = $request->input('difficulty');
        $excludeHashes = (array) $request->input('exclude_hashes', []);
        $excludeAnswerHashes = (array) $request->input('exclude_answer_hashes', []);

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        $seenIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'trivia')
            ->pluck('content_id')
            ->all();

        $resolvedSlugs = [];
        if (!empty($categoriesParam)) {
            $rawSlugs = array_filter(array_map('trim', explode(',', $categoriesParam)));
            if (!empty($rawSlugs) && !in_array('all', $rawSlugs, true)) {
                $resolvedSlugs = array_values(array_unique(array_map([Category::class, 'canonicalSlug'], $rawSlugs)));
            }
        }

        $query = Question::with('category')
            ->where('status', 'active')
            ->where('is_active', true);

        if (!empty($resolvedSlugs)) {
            $query->whereHas('category', fn ($q) => $q->whereIn('slug', $resolvedSlugs));
        }

        if (!empty($difficulty) && $difficulty !== 'all' && $difficulty !== 'mixed') {
            $query->where('difficulty', $difficulty);
        }

        $seenPrompts = !empty($seenIds) ? Question::whereIn('id', $seenIds)->pluck('prompt_ar')->all() : [];

        // في حال تعدد الأقسام المختارة: جلب مرشحين موزعين بتوازن بين الأقسام
        $candidates = collect();
        if (count($resolvedSlugs) > 1) {
            $perCatCount = (int) ceil(($count * 3) / count($resolvedSlugs));
            foreach ($resolvedSlugs as $catSlug) {
                $catCandidates = (clone $query)->whereHas('category', fn ($q) => $q->where('slug', $catSlug))
                    ->whereNotIn('id', $seenIds)
                    ->inRandomOrder()
                    ->limit($perCatCount)
                    ->get();
                $candidates = $candidates->merge($catCandidates);
            }
            $candidates = $candidates->shuffle();
        } else {
            $candidates = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->limit($count * 4)->get();
        }

        $selected = [];
        $selectedHashes = $excludeHashes;
        $selectedAnswerHashes = $excludeAnswerHashes;
        $selectedPrompts = $seenPrompts;

        foreach ($candidates as $cand) {
            if (count($selected) >= $count) {
                break;
            }

            $pHash = ArabicNormalizer::promptHash($cand->prompt_ar . ' ' . ($cand->emoji_prompt ?? ''));
            if (in_array($pHash, $selectedHashes, true)) {
                continue;
            }

            $rawCorrect = $cand->options[$cand->correct_index] ?? '';
            $catSlug = Category::canonicalSlug($cand->category?->slug ?? 'general');
            $aHash = ArabicNormalizer::answerHash($catSlug, $rawCorrect);
            if (in_array($aHash, $selectedAnswerHashes, true)) {
                continue;
            }

            // فحص التشابه النصي
            $hasHighSimilarity = false;
            foreach ($selectedPrompts as $prevPrompt) {
                if (ArabicNormalizer::jaccardSimilarity($cand->prompt_ar, $prevPrompt) >= 0.85) {
                    $hasHighSimilarity = true;
                    break;
                }
            }
            if ($hasHighSimilarity) {
                continue;
            }

            $selected[] = $cand;
            $selectedHashes[] = $pHash;
            $selectedAnswerHashes[] = $aHash;
            $selectedPrompts[] = $cand->prompt_ar;
        }

        if (count($selected) < $count) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'الأسئلة غير المشاهدة المتاحة أقل من العدد المطلوب',
                'available' => count($selected),
                'required' => $count,
            ], 404);
        }

        // تأكيد نهائي صارم (Assertion) على كل عنصر في الدفعة
        foreach ($selected as $q) {
            $qSlug = Category::canonicalSlug($q->category?->slug ?? 'general');
            if (!empty($resolvedSlugs) && !in_array($qSlug, $resolvedSlugs, true)) {
                \Illuminate\Support\Facades\Log::critical("Category leak in batch blocked: Question {$q->id} with slug {$qSlug}");
                return response()->json([
                    'success' => false,
                    'error' => 'category_mismatch',
                    'message' => 'تم رصد تسرب قسم غير مصرح به في الدفعة وإسقاطه',
                ], 500);
            }
        }

        // حجز فوري للمحتوى لأجهزة الغرفة
        foreach ($selected as $q) {
            if (!empty($deviceIds)) {
                DeviceContentHistory::markSeen($deviceIds, 'trivia', $q->id);
            }
            $q->increment('times_served');
        }

        $data = array_map(function ($q) {
            return [
                'id' => $q->id,
                'category_id' => $q->category_id,
                'category_slug' => Category::canonicalSlug($q->category?->slug ?? 'general'),
                'type' => $q->type,
                'prompt_ar' => $q->prompt_ar,
                'emoji_prompt' => $q->emoji_prompt,
                'options' => $q->options,
                'correct_index' => 0, // آمن
                'difficulty' => $q->difficulty,
                'explanation_ar' => $q->explanation_ar,
                'source' => $q->source,
            ];
        }, $selected);

        return response()->json([
            'success' => true,
            'count' => count($data),
            'data' => $data,
        ]);
    }

    /**
     * جلب دفعة كاملة لكلمات مثّل ومتتكلمش مسبقاً (Pre-buffering):
     */
    public function getNextCharadesBatch(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $count = (int) min(40, max(1, $request->input('count', 15)));
        $rawCat = $request->input('category');
        $canonicalCat = $rawCat ? Category::canonicalSlug((string) $rawCat) : null;
        $excludeWords = (array) $request->input('exclude_words', []);

        $session = RoomSession::where('room_code', $roomCode)->first();
        $deviceIds = $session ? $session->activeDeviceIds() : [];
        if (!empty($callerDeviceId) && !in_array($callerDeviceId, $deviceIds, true)) {
            $deviceIds[] = $callerDeviceId;
        }

        $seenIds = DeviceContentHistory::whereIn('device_id', $deviceIds)
            ->where('content_type', 'charades')
            ->pluck('content_id')
            ->all();

        $query = CharadesWord::with('category')->where('status', 'active')->where('is_active', true);
        if (!empty($canonicalCat) && !in_array($canonicalCat, ['mixed', 'all'], true)) {
            $query->whereHas('category', fn ($q) => $q->where('slug', $canonicalCat));
        }

        $candidates = (clone $query)->whereNotIn('id', $seenIds)->inRandomOrder()->limit($count * 3)->get();

        $selected = [];
        $selectedWords = $excludeWords;

        foreach ($candidates as $cand) {
            if (count($selected) >= $count) {
                break;
            }
            if (!in_array($cand->word_ar, $selectedWords, true)) {
                $selected[] = $cand;
                $selectedWords[] = $cand->word_ar;
            }
        }

        if (count($selected) < $count) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'الكلمات غير المشاهدة المتاحة أقل من العدد المطلوب',
                'available' => count($selected),
                'required' => $count,
            ], 404);
        }

        // تأكيد نهائي صارم (Assertion)
        if (!empty($canonicalCat) && !in_array($canonicalCat, ['mixed', 'all'], true)) {
            foreach ($selected as $w) {
                $wCat = Category::canonicalSlug($w->category?->slug ?? '');
                if ($wCat !== $canonicalCat) {
                    \Illuminate\Support\Facades\Log::critical("Charades batch leak: {$wCat} != {$canonicalCat}");
                    return response()->json([
                        'success' => false,
                        'error' => 'category_mismatch',
                        'message' => 'تسرب قسم تمثيل في الدفعة',
                    ], 500);
                }
            }
        }

        foreach ($selected as $w) {
            if (!empty($deviceIds)) {
                DeviceContentHistory::markSeen($deviceIds, 'charades', $w->id);
            }
            $w->increment('times_served');
        }

        return response()->json([
            'success' => true,
            'count' => count($selected),
            'data' => array_map(fn ($w) => [
                'id' => $w->id,
                'word_ar' => $w->word_ar,
            ], $selected),
        ]);
    }

    /**
     * جلب دفعات جولات مين الجاسوس مسبقاً (Pre-buffering):
     */
    public function getNextSpyBatch(Request $request, string $roomCode): JsonResponse
    {
        $roomCode = strtoupper(trim($roomCode));
        $callerDeviceId = (string) $request->header('X-Device-Id', '');
        $rounds = (int) min(10, max(1, $request->input('rounds', 3)));
        $rawPack = (string) $request->input('pack_slug', $request->input('pack', 'places'));
        $packSlug = ($rawPack === 'food') ? 'foods' : $rawPack;

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

        if (!empty($packSlug) && !in_array($packSlug, ['mixed', 'all'], true)) {
            $query->where('pack_slug', $packSlug);
        }

        $groups = (clone $query)->whereNotIn('id', $seenGroupIds)
            ->inRandomOrder()
            ->limit($rounds)
            ->get();

        if ($groups->count() < $rounds) {
            return response()->json([
                'success' => false,
                'error' => 'exhausted',
                'message' => 'مجموعات الجاسوس غير المشاهدة لا تكفي عدد الجولات',
                'available' => $groups->count(),
                'required' => $rounds,
            ], 404);
        }

        // تأكيد نهائي صارم (Assertion)
        if (!empty($packSlug) && !in_array($packSlug, ['mixed', 'all'], true)) {
            foreach ($groups as $g) {
                if ($g->pack_slug !== $packSlug) {
                    \Illuminate\Support\Facades\Log::critical("Spy batch pack leak: {$g->pack_slug} != {$packSlug}");
                    return response()->json([
                        'success' => false,
                        'error' => 'category_mismatch',
                        'message' => 'تسرب حزمة جاسوس في الدفعة',
                    ], 500);
                }
            }
        }

        $roundsData = [];
        $prevWord = null;

        foreach ($groups as $group) {
            $words = $group->words->pluck('word_ar')->all();
            if (count($words) < 4) {
                continue;
            }

            $secretCandidates = array_values(array_filter($words, fn ($w) => $w !== $prevWord));
            $secretWord = !empty($secretCandidates) ? $secretCandidates[array_rand($secretCandidates)] : $words[0];
            $prevWord = $secretWord;

            $otherWords = array_values(array_filter($words, fn ($w) => $w !== $secretWord));
            shuffle($otherWords);
            $distractors = array_slice($otherWords, 0, 3);
            $spyChoices = array_merge([$secretWord], $distractors);
            shuffle($spyChoices);

            if (!empty($deviceIds)) {
                DeviceContentHistory::markSeen($deviceIds, 'spy_group', $group->id);
            }
            $group->increment('times_served');

            $roundsData[] = [
                'group_id' => $group->id,
                'category_name' => $group->title_ar,
                'secret_word' => $secretWord,
                'spy_choices' => $spyChoices,
                'theme' => $group->theme,
            ];
        }

        return response()->json([
            'success' => true,
            'rounds' => count($roundsData),
            'data' => $roundsData,
        ]);
    }
}
