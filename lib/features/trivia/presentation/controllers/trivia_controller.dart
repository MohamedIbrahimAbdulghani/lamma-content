// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
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
];

class TriviaGameNotifier extends StateNotifier<TriviaGameState> {
  final Map<String, dynamic>? scoringSettings;
  final void Function(List<PlayerModel>)? onPlayersUpdated;

  Timer? _questionTimer;
  Timer? _revealTimer;
  Timer? _leaderboardTimer;
  Timer? _leaderboardPeriodicTimer;

  TriviaGameNotifier({
    List<QuestionModel>? initialQuestions,
    List<PlayerModel>? initialPlayers,
    int totalSeconds = 15,
    this.scoringSettings,
    this.onPlayersUpdated,
    String myPlayerId = '1',
    bool autoStart = true,
  }) : super(TriviaGameState(
          questions: initialQuestions ?? kDefaultTriviaQuestions,
          totalSeconds: totalSeconds,
          secondsLeft: totalSeconds,
          players: initialPlayers ?? _buildDefaultPlayers(),
          myPlayerId: myPlayerId,
        )) {
    if (autoStart && state.questions.isNotEmpty) {
      _startQuestionTimer();
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

  /// Lock answer after first tap and transition to reveal screen for 2s.
  void submitAnswer(int optionIndex) {
    if (state.isAnswerLocked || state.phase != TriviaPhase.question) {
      return;
    }

    _questionTimer?.cancel();

    final currentQ = state.currentQuestion;
    if (currentQ == null) return;

    final isCorrect = (optionIndex == currentQ.correctIndex);
    final earnedPoints = TriviaScorer.calculateFromSettings(
      isCorrect: isCorrect,
      remainingSeconds: state.secondsLeft,
      totalSeconds: state.totalSeconds,
      scoringSettings: scoringSettings,
    );

    // Add points immediately to player.score
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

  /// When timer ends with no answer, lock answer and auto-advance to reveal screen.
  void onTimeOut() {
    if (state.isAnswerLocked || state.phase != TriviaPhase.question) {
      return;
    }

    _questionTimer?.cancel();

    state = state.copyWith(
      selectedOptionIndex: null,
      isAnswerLocked: true,
      answerResult: TriviaAnswerResult.wrong,
      lastEarnedPoints: 0,
      phase: TriviaPhase.reveal,
    );

    _startRevealTimer();
  }

  /// 2-second reveal timer. Automatically advances to leaderboard screen (never stuck).
  void _startRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 2), () {
      advanceFromReveal();
    });
  }

  /// Advance from reveal screen 18/19 to leaderboard screen 21.
  void advanceFromReveal() {
    _revealTimer?.cancel();
    state = state.copyWith(
      phase: TriviaPhase.leaderboard,
      leaderboardSecondsLeft: 3,
    );
    _startLeaderboardTimer();
  }

  /// 3-second leaderboard timer. Automatically advances to next question or final results.
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

  /// Advance to next question or final results screen 36.
  void advanceFromLeaderboard() {
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();

    if (state.currentQuestionIndex + 1 < state.totalQuestions) {
      final nextIndex = state.currentQuestionIndex + 1;
      state = state.copyWith(
        currentQuestionIndex: nextIndex,
        phase: TriviaPhase.question,
        secondsLeft: state.totalSeconds,
        selectedOptionIndex: null,
        isAnswerLocked: false,
        answerResult: TriviaAnswerResult.none,
        lastEarnedPoints: 0,
        leaderboardSecondsLeft: 3,
      );
      _startQuestionTimer();
    } else {
      state = state.copyWith(phase: TriviaPhase.completed);
    }
  }

  /// Restart game with fresh scores.
  void restartGame({List<QuestionModel>? newQuestions}) {
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    _leaderboardTimer?.cancel();
    _leaderboardPeriodicTimer?.cancel();

    final resetPlayers = state.players.map((p) => p.copyWith(score: 0)).toList();

    state = TriviaGameState(
      questions: newQuestions ?? state.questions,
      totalSeconds: state.totalSeconds,
      secondsLeft: state.totalSeconds,
      players: resetPlayers,
      myPlayerId: state.myPlayerId,
    );

    _startQuestionTimer();
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
  final triviaSettings = ref.watch(triviaSettingsProvider);
  final bootstrap = ref.watch(bootstrapProvider);
  final scoringSettings = bootstrap.data?.settings['scoring'] as Map<String, dynamic>?;
  final roomState = ref.watch(gameRoomProvider);
  final currentPlayerName = ref.watch(currentPlayerNameProvider);
  final currentPlayerAvatar = ref.watch(currentPlayerAvatarProvider);

  // Use players from roomState if present; else build default with user profile
  List<PlayerModel> initialPlayers;
  if (roomState.players.isNotEmpty) {
    initialPlayers = roomState.players;
  } else {
    initialPlayers = TriviaGameNotifier._buildDefaultPlayers(
      currentName: currentPlayerName,
      currentAvatar: currentPlayerAvatar,
    );
  }

  return TriviaGameNotifier(
    totalSeconds: triviaSettings.timePerQuestion,
    scoringSettings: scoringSettings,
    initialPlayers: initialPlayers,
    myPlayerId: roomState.myPlayerId.isNotEmpty ? roomState.myPlayerId : '1',
    onPlayersUpdated: (players) {
      ref.read(gameRoomProvider.notifier).setPlayers(players);
    },
  );
});
