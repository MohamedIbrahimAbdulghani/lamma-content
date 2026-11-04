// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lamma_party_game_app/core/utils/category_localization.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/features/trivia/domain/trivia_scorer.dart';
import 'trivia_state.dart';

const List<QuestionModel> kDefaultTriviaQuestions = [
  QuestionModel(
    id: 1,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'مين صاحب الإفيه الشهير: يا صفيحة زبالة منورة؟',
    options: ['عادل إمام', 'محمد هنيدي', 'أحمد حلمي', 'نجيب الريحاني'],
    correctIndex: 1,
    difficulty: 'medium',
    source: 'seed',
  ),
  QuestionModel(
    id: 2,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'إيه اسم بطل فيلم الكيف المشهور بالدكتور؟',
    options: ['البهظ بيه', 'دكتور صلاح', 'مزاجنجي', 'عبده كفتة'],
    correctIndex: 1,
    difficulty: 'easy',
    source: 'seed',
  ),
  QuestionModel(
    id: 3,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين هو الهداف التاريخي للنادي الأهلي في الدوري المصري؟',
    options: ['محمود الخطيب', 'محمد أبو تريكة', 'حسام حسن', 'عماد متعب'],
    correctIndex: 0,
    difficulty: 'medium',
    source: 'seed',
  ),
  QuestionModel(
    id: 4,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'مين مخرج فيلم "الأرض" الشهير؟',
    options: ['يوسف شاهين', 'صلاح أبو سيف', 'عاطف الطيب', 'داود عبد السيد'],
    correctIndex: 0,
    difficulty: 'medium',
    source: 'seed',
  ),
  QuestionModel(
    id: 5,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'في فيلم الناظر، مين جسد شخصية "عاطف"؟',
    options: ['أحمد حلمي', 'علاء ولي الدين', 'محمد سعد', 'حسن حسني'],
    correctIndex: 0,
    difficulty: 'easy',
    source: 'seed',
  ),
  QuestionModel(
    id: 6,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'منتخب مصر فاز بكأس أمم إفريقيا كام مرة تاريخياً؟',
    options: ['5 مرات', '6 مرات', '7 مرات', '8 مرات'],
    correctIndex: 2,
    difficulty: 'easy',
    source: 'seed',
  ),
  QuestionModel(
    id: 7,
    categoryId: 4,
    categorySlug: 'history',
    type: 'mcq',
    promptAr: 'مين بنى قلعة الجبل في القاهرة؟',
    options: ['صلاح الدين الأيوبي', 'محمد علي باشا', 'الظاهر بيبرس', 'قطز'],
    correctIndex: 0,
    difficulty: 'easy',
    source: 'seed',
  ),
  QuestionModel(
    id: 8,
    categoryId: 3,
    categorySlug: 'afeehat',
    type: 'mcq',
    promptAr: 'صاحب إفيه: "كله ضرب ضرب مفيش شتيمة؟"',
    options: ['عادل إمام', 'محمد سعد', 'فؤاد المهندس', 'سعيد صالح'],
    correctIndex: 0,
    difficulty: 'easy',
    source: 'seed',
  ),
  QuestionModel(
    id: 9,
    categoryId: 1,
    categorySlug: 'movies',
    type: 'mcq',
    promptAr: 'إيه اسم القرية في فيلم "الزوجة الثانية"؟',
    options: ['ميت العطار', 'ميت حبيب', 'ميت غمر', 'كفر الدوار'],
    correctIndex: 0,
    difficulty: 'hard',
    source: 'seed',
  ),
  QuestionModel(
    id: 10,
    categoryId: 2,
    categorySlug: 'sports',
    type: 'mcq',
    promptAr: 'مين صاحب هدف فوز الزمالك بكأس الكونفدرالية 2019؟',
    options: ['محمود علاء', 'يوسف أوباما', 'فرجاني ساسي', 'طارق حامد'],
    correctIndex: 0,
    difficulty: 'medium',
    source: 'seed',
  ),
];

class TriviaGameNotifier extends StateNotifier<TriviaGameState> {
  final Map<String, dynamic>? scoringSettings;
  final void Function(List<PlayerModel>)? onPlayersUpdated;
  final bool startWithSelection;
  final GameContentService? contentService;

  Timer? _questionTimer;
  Timer? _revealTimer;
  Timer? _leaderboardTimer;
  Timer? _leaderboardPeriodicTimer;

  final String? roomCode;
  final dynamic roomServer;

  TriviaGameNotifier({
    List<QuestionModel>? initialQuestions,
    List<PlayerModel>? initialPlayers,
    int totalSeconds = 15,
    this.scoringSettings,
    this.onPlayersUpdated,
    String myPlayerId = '1',
    bool autoStart = true,
    this.startWithSelection = false,
    this.contentService,
    this.roomCode,
    this.roomServer,
  }) : super(TriviaGameState(
          questions: initialQuestions ?? kDefaultTriviaQuestions,
          totalSeconds: totalSeconds,
          secondsLeft: totalSeconds,
          phase: startWithSelection ? TriviaPhase.questionSelection : TriviaPhase.question,
          players: initialPlayers ?? _buildDefaultPlayers(),
          myPlayerId: myPlayerId,
          playedQuestionIndices: const [],
        )) {
    if (autoStart && !startWithSelection && state.questions.isNotEmpty) {
      _startQuestionTimer();
      _recordCurrentQuestionPresented();

      // تجهيز مسبق في الخلفية للجولة التالية أثناء سير الجولة الأولى
      if (contentService != null && roomCode != null && roomCode!.isNotEmpty) {
        contentService!.prebufferNextTriviaGame(
          roomCode: roomCode!,
          count: state.questions.length,
          categories: state.questions.map((q) => q.categorySlug).toSet().toList(),
          difficulty: 'all',
          externalSeenPromptHashes: roomServer?.getAllSeenTriviaPromptHashes(),
          externalSeenAnswerHashes: roomServer?.getAllSeenTriviaAnswerHashes(),
        );
      }
    }
  }

  static List<PlayerModel> _buildDefaultPlayers({
    String currentName = 'أحمد',
    String currentAvatar = '🦁',
  }) {
    return [
      PlayerModel(id: '1', name: currentName, avatar: currentAvatar, score: 0),
      const PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 0),
      const PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 0),
      const PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 0),
      const PlayerModel(id: '5', name: 'عمر', avatar: '🐯', score: 0),
    ];
  }

  void _recordCurrentQuestionPresented() {
    final curQ = state.currentQuestion;
    if (curQ != null && contentService != null) {
      contentService!.markTriviaQuestionPresented(curQ);
    }
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsLeft > 1) {
        state = state.copyWith(secondsLeft: state.secondsLeft - 1);
      } else {
        timer.cancel();
        state = state.copyWith(secondsLeft: 0);
        onTimeOut();
      }
    });
  }

  /// اختيار سؤال محدد من القائمة وبدء لعبه
  void selectQuestion(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= state.questions.length) return;

    final played = List<int>.from(state.playedQuestionIndices);
    if (!played.contains(questionIndex)) {
      played.add(questionIndex);
    }

    state = state.copyWith(
      currentQuestionIndex: questionIndex,
      playedQuestionIndices: played,
      phase: TriviaPhase.question,
      secondsLeft: state.totalSeconds,
      clearSelectedOption: true,
      isAnswerLocked: false,
      answerResult: TriviaAnswerResult.none,
      lastEarnedPoints: 0,
    );

    _startQuestionTimer();
    _recordCurrentQuestionPresented();
  }

  /// اختيار سؤال عشوائي من الأسئلة المتبقية
  void selectRandomQuestion() {
    final remaining = state.remainingQuestionIndices;
    if (remaining.isNotEmpty) {
      final randomIndex = remaining[Random().nextInt(remaining.length)];
      selectQuestion(randomIndex);
    } else if (state.questions.isNotEmpty) {
      selectQuestion(Random().nextInt(state.questions.length));
    }
  }

  /// بنقفل الإجابة بعد أول ضغطة وبننقل لشاشة الكشف لمدة 2 ثانية
  void submitAnswer(int optionIndex) {
    if (state.isAnswerLocked || state.phase != TriviaPhase.question) {
      return;
    }

    _questionTimer?.cancel();

    final currentQ = state.currentQuestion;
    if (currentQ == null) return;

    final isCorrect = (optionIndex == currentQ.correctIndex);
    final earnedPoints = currentQ.points > 100
        ? TriviaScorer.calculateScore(isCorrect: isCorrect, questionPoints: currentQ.points)
        : TriviaScorer.calculateScore(
            isCorrect: isCorrect,
            questionPoints: currentQ.points,
            remainingSeconds: state.secondsLeft,
            totalSeconds: state.totalSeconds,
          );

    // إضافة النقط للاعب
    final updatedPlayers = state.players.map((p) {
      if (p.id == state.myPlayerId) {
        return p.copyWith(score: p.score + earnedPoints);
      }
      return p;
    }).toList();

    state = state.copyWith(
      selectedOptionIndex: optionIndex,
      isAnswerLocked: true,
      answerResult: isCorrect ? TriviaAnswerResult.correct : TriviaAnswerResult.wrong,
      lastEarnedPoints: earnedPoints,
      players: updatedPlayers,
      phase: TriviaPhase.reveal,
    );

    onPlayersUpdated?.call(updatedPlayers);
    _startRevealTimer();
  }

  /// لما الوقت يخلص من غير إجابة، بنقفل وننقل لشاشة الكشف
  void onTimeOut() {
    if (state.isAnswerLocked || state.phase != TriviaPhase.question) {
      return;
    }

    _questionTimer?.cancel();

    state = state.copyWith(
      clearSelectedOption: true,
      isAnswerLocked: true,
      answerResult: TriviaAnswerResult.wrong,
      lastEarnedPoints: 0,
      phase: TriviaPhase.reveal,
    );

    _startRevealTimer();
  }

  /// تايمر الكشف 1.5 ثانية، بينقل تلقائياً للترتيب
  void _startRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 1500), () {
      advanceFromReveal();
    });
  }

  /// الانتقال من الكشف للترتيب
  void advanceFromReveal() {
    _revealTimer?.cancel();
    state = state.copyWith(
      phase: TriviaPhase.leaderboard,
      leaderboardSecondsLeft: 3,
    );
    _startLeaderboardTimer();
  }

  /// تايمر الترتيب 3 ثواني
  void _startLeaderboardTimer() {
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();

    _leaderboardPeriodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.leaderboardSecondsLeft > 1) {
        state = state.copyWith(leaderboardSecondsLeft: state.leaderboardSecondsLeft - 1);
      } else {
        timer.cancel();
      }
    });

    _leaderboardTimer = Timer(const Duration(seconds: 3), () {
      advanceFromLeaderboard();
    });
  }

  /// الانتقال للسؤال التالي أو شاشة اختيار السؤال أو شاشة النتائج النهائية
  void advanceFromLeaderboard() {
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();

    if (startWithSelection) {
      final remaining = state.remainingQuestionIndices;
      final hasMore = remaining.isNotEmpty && state.playedQuestionIndices.length < state.totalQuestions;

      if (hasMore) {
        state = state.copyWith(
          phase: TriviaPhase.questionSelection,
          clearSelectedOption: true,
          isAnswerLocked: false,
          answerResult: TriviaAnswerResult.none,
          lastEarnedPoints: 0,
          leaderboardSecondsLeft: 3,
        );
      } else {
        state = state.copyWith(phase: TriviaPhase.completed);
      }
    } else {
      // النمط التسلسلي التلقائي (المستخدم في الاختبارات واللعب الخطي)
      if (state.currentQuestionIndex + 1 < state.totalQuestions) {
        final nextIndex = state.currentQuestionIndex + 1;
        state = state.copyWith(
          currentQuestionIndex: nextIndex,
          phase: TriviaPhase.question,
          secondsLeft: state.totalSeconds,
          clearSelectedOption: true,
          isAnswerLocked: false,
          answerResult: TriviaAnswerResult.none,
          lastEarnedPoints: 0,
          leaderboardSecondsLeft: 3,
        );
        _startQuestionTimer();
        _recordCurrentQuestionPresented();
      } else {
        state = state.copyWith(phase: TriviaPhase.completed);
      }
    }
  }

  /// إعادة اللعبة بأسئلة وسكور جديد مع تطبيق الإعدادات المختارة
  Future<void> restartGame({
    List<QuestionModel>? newQuestions,
    int? questionCount,
    int? totalSeconds,
    List<String>? categories,
    String? difficulty,
    BootstrapData? bootstrapData,
  }) async {
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();

    final resetPlayers = state.players.map((p) => p.copyWith(score: 0)).toList();
    onPlayersUpdated?.call(resetPlayers);

    List<QuestionModel> questionsToUse = newQuestions ?? [];
    if (questionsToUse.isEmpty && contentService != null) {
      final effectiveRoomCode = roomCode ?? '';
      final neededCount = questionCount ?? (state.questions.isNotEmpty ? state.questions.length : 10);
      final cats = categories ?? (state.questions.map((q) => q.categorySlug).toSet().toList());
      final diff = difficulty ?? 'all';

      // 1. استهلاك فوري للمحتوى المجهز مسبقاً والمحجوز لهذه الغرفة
      if (effectiveRoomCode.isNotEmpty) {
        final prebuffered = contentService!.consumePrebufferedTrivia(
          effectiveRoomCode,
          count: neededCount,
          categories: cats,
          difficulty: diff,
        );
        if (prebuffered != null && prebuffered.length >= neededCount) {
          questionsToUse = prebuffered;
          // إطلاق حجز مسبق في الخلفية فوراً للعبة التالية
          unawaited(contentService!.prebufferNextTriviaGame(
            roomCode: effectiveRoomCode,
            count: neededCount,
            categories: cats,
            difficulty: diff,
            externalSeenPromptHashes: roomServer?.getAllSeenTriviaPromptHashes(),
            externalSeenAnswerHashes: roomServer?.getAllSeenTriviaAnswerHashes(),
          ));
        }
      }

      // 2. إذا لم يكتمل التجهيز المسبق، جلب بدفعة واحدة
      if (questionsToUse.isEmpty) {
        questionsToUse = await contentService!.getTriviaQuestions(
          count: neededCount,
          categories: cats,
          difficulty: diff,
          bootstrapData: bootstrapData,
          roomCode: effectiveRoomCode.isNotEmpty ? effectiveRoomCode : null,
          externalSeenPromptHashes: roomServer?.getAllSeenTriviaPromptHashes(),
          externalSeenAnswerHashes: roomServer?.getAllSeenTriviaAnswerHashes(),
        );
      }
    }

    if (questionsToUse.isEmpty) {
      final categoryLabel = CategoryLocalization.getTriviaCategoriesLabel(categories ?? []);
      throw InsufficientTriviaQuestionsException(
        category: categoryLabel,
        available: 0,
        requiredCount: questionCount ?? 10,
      );
    }

    final seconds = totalSeconds ?? state.totalSeconds;

    // تحديث سيرفر الغرفة للملتيبلاير لبدء السؤال الأول لدى كافة الأجهزة الحاضرة فوراً
    if (roomServer != null) {
      roomServer.setPlayers(resetPlayers);
      roomServer.startTriviaGame(questionsToUse, timePerQuestion: seconds);
    }

    state = TriviaGameState(
      questions: questionsToUse,
      totalSeconds: seconds,
      secondsLeft: seconds,
      phase: startWithSelection ? TriviaPhase.questionSelection : TriviaPhase.question,
      players: resetPlayers,
      myPlayerId: state.myPlayerId,
      playedQuestionIndices: const [],
    );

    if (!startWithSelection && questionsToUse.isNotEmpty) {
      _startQuestionTimer();
      _recordCurrentQuestionPresented();
    }
  }

  /// إلغاء مؤقتات الجولة الحالية فوراً عند الرجوع للوبي
  void cancelRound() {
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();
    super.dispose();
  }
}

final triviaGameProvider = StateNotifierProvider<TriviaGameNotifier, TriviaGameState>((ref) {
  // مراقبة إعدادات تحدي الشلة لضمان استجابة وتحديث البروفايدر بالقيم المحفوظة
  final triviaSettings = ref.watch(triviaSettingsProvider);
  final bootstrap = ref.read(bootstrapProvider);
  final scoringSettings = bootstrap.data?.settings['scoring'] as Map<String, dynamic>?;
  final roomState = ref.read(gameRoomProvider);
  final roomServer = ref.read(gameRoomProvider.notifier).server;
  final currentPlayerName = ref.read(currentPlayerNameProvider);
  final currentPlayerAvatar = ref.read(currentPlayerAvatarProvider);
  final contentService = ref.read(gameContentServiceProvider);

  List<PlayerModel> initialPlayers;
  if (roomState.players.isNotEmpty) {
    initialPlayers = roomState.players.map((p) => p.copyWith(score: 0)).toList();
  } else {
    initialPlayers = TriviaGameNotifier._buildDefaultPlayers(
      currentName: currentPlayerName,
      currentAvatar: currentPlayerAvatar,
    );
  }

  // إذا كانت هناك أسئلة جاهزة وموزعة من الغرفة الجماعية نستخدمها مباشرة
  List<QuestionModel> selectedQuestions;
  if (roomState.triviaQuestions.isNotEmpty) {
    selectedQuestions = roomState.triviaQuestions;
  } else {
    final questions = List<QuestionModel>.from(kDefaultTriviaQuestions)..shuffle(Random());
    final count = triviaSettings.questionsCount > 0 ? triviaSettings.questionsCount : 10;
    selectedQuestions = questions.take(count).toList();
  }

  return TriviaGameNotifier(
    initialQuestions: selectedQuestions,
    totalSeconds: triviaSettings.timePerQuestion,
    scoringSettings: scoringSettings,
    initialPlayers: initialPlayers,
    myPlayerId: roomState.myPlayerId.isNotEmpty ? roomState.myPlayerId : '1',
    startWithSelection: false,
    contentService: contentService,
    roomCode: roomState.roomCode,
    roomServer: roomServer,
    onPlayersUpdated: (players) {
      ref.read(gameRoomProvider.notifier).setPlayers(players);
    },
  );
});
