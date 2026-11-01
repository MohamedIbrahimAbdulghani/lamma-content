// Lamma - by Mohamed Ibrahim

import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';

enum TriviaPhase {
  questionSelection,
  question,
  reveal,
  leaderboard,
  completed,
}

enum TriviaAnswerResult {
  none,
  correct,
  wrong,
}

class TriviaGameState {
  final List<QuestionModel> questions;
  final int currentQuestionIndex;
  final int secondsLeft;
  final int totalSeconds;
  final TriviaPhase phase;
  final int? selectedOptionIndex;
  final bool isAnswerLocked;
  final TriviaAnswerResult answerResult;
  final int lastEarnedPoints;
  final List<PlayerModel> players;
  final String myPlayerId;
  final int leaderboardSecondsLeft;
  final List<int> playedQuestionIndices;

  const TriviaGameState({
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.secondsLeft = 15,
    this.totalSeconds = 15,
    this.phase = TriviaPhase.question,
    this.selectedOptionIndex,
    this.isAnswerLocked = false,
    this.answerResult = TriviaAnswerResult.none,
    this.lastEarnedPoints = 0,
    this.players = const [],
    this.myPlayerId = '1',
    this.leaderboardSecondsLeft = 3,
    this.playedQuestionIndices = const [],
  });

  QuestionModel? get currentQuestion =>
      (currentQuestionIndex >= 0 && currentQuestionIndex < questions.length)
          ? questions[currentQuestionIndex]
          : null;

  int get totalQuestions => questions.length;

  bool get isLastQuestion =>
      currentQuestionIndex >= totalQuestions - 1 ||
      (totalQuestions > 0 && playedQuestionIndices.length >= totalQuestions);

  List<int> get remainingQuestionIndices {
    final list = <int>[];
    for (var i = 0; i < questions.length; i++) {
      if (!playedQuestionIndices.contains(i)) {
        list.add(i);
      }
    }
    return list;
  }

  List<PlayerModel> get sortedPlayers =>
      [...players]..sort((a, b) => b.score.compareTo(a.score));

  TriviaGameState copyWith({
    List<QuestionModel>? questions,
    int? currentQuestionIndex,
    int? secondsLeft,
    int? totalSeconds,
    TriviaPhase? phase,
    int? selectedOptionIndex,
    bool clearSelectedOption = false,
    bool? isAnswerLocked,
    TriviaAnswerResult? answerResult,
    int? lastEarnedPoints,
    List<PlayerModel>? players,
    String? myPlayerId,
    int? leaderboardSecondsLeft,
    List<int>? playedQuestionIndices,
  }) {
    return TriviaGameState(
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      phase: phase ?? this.phase,
      selectedOptionIndex: clearSelectedOption
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      isAnswerLocked: isAnswerLocked ?? this.isAnswerLocked,
      answerResult: answerResult ?? this.answerResult,
      lastEarnedPoints: lastEarnedPoints ?? this.lastEarnedPoints,
      players: players ?? this.players,
      myPlayerId: myPlayerId ?? this.myPlayerId,
      leaderboardSecondsLeft:
          leaderboardSecondsLeft ?? this.leaderboardSecondsLeft,
      playedQuestionIndices:
          playedQuestionIndices ?? this.playedQuestionIndices,
    );
  }
}
