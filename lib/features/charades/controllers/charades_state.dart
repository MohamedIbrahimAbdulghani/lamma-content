// Lamma - by Mohamed Ibrahim

import 'package:lamma_party_game_app/data/models/player_model.dart';

class CharadesGameState {
  final List<String> words;
  final int currentWordIndex;
  final int secondsLeft;
  final int totalSeconds;
  final int currentPlayerIndex;
  final int currentRound;
  final int totalRounds;
  final List<Map<String, dynamic>> roundHistory; // [{'word': '...', 'correct': true/false}]
  final List<PlayerModel> players;
  final bool isRoundActive;
  final bool isGameCompleted;
  final bool isLoading;
  final int wordsPerTurn; // 0 = مفتوح (بلا حد), 5, 10, 15, 20, 30

  const CharadesGameState({
    this.words = const [],
    this.currentWordIndex = 0,
    this.secondsLeft = 60,
    this.totalSeconds = 60,
    this.currentPlayerIndex = 0,
    this.currentRound = 1,
    this.totalRounds = 2,
    this.roundHistory = const [],
    this.players = const [],
    this.isRoundActive = false,
    this.isGameCompleted = false,
    this.isLoading = false,
    this.wordsPerTurn = 10,
  });

  PlayerModel? get currentPlayer =>
      (currentPlayerIndex >= 0 && currentPlayerIndex < players.length)
          ? players[currentPlayerIndex]
          : null;

  PlayerModel? get nextPlayer {
    if (players.isEmpty) return null;
    final nextIdx = (currentPlayerIndex + 1) % players.length;
    return players[nextIdx];
  }

  bool get hasWords => words.isNotEmpty;

  String get currentWord {
    if (words.isEmpty) return '';
    if (currentWordIndex >= 0 && currentWordIndex < words.length) {
      return words[currentWordIndex];
    }
    return words.last;
  }

  /// إجمالي الكلمات التي عُرضت في هذا الدور (عرفوها + تخطي)
  int get wordsAttemptedInRound => roundHistory.length;

  /// رقم الكلمة الحالية المعروضة للاعب في هذا الدور
  int get currentWordNumberInTurn =>
      (wordsAttemptedInRound + 1).clamp(1, wordsPerTurn > 0 ? wordsPerTurn : 9999);

  /// هل هناك حد أقصى للكلمات أم مفتوح بالوقت فقط
  bool get isWordsLimitEnabled => wordsPerTurn > 0;

  /// هل تحقق شرط انتهاء الكلمات لهذا الدور
  bool get isWordsLimitReached =>
      isWordsLimitEnabled && wordsAttemptedInRound >= wordsPerTurn;

  int get correctCountInRound =>
      roundHistory.where((item) => item['correct'] == true).length;

  int get passedCountInRound =>
      roundHistory.where((item) => item['correct'] == false).length;

  List<PlayerModel> get sortedPlayers =>
      [...players]..sort((a, b) => b.score.compareTo(a.score));

  CharadesGameState copyWith({
    List<String>? words,
    int? currentWordIndex,
    int? secondsLeft,
    int? totalSeconds,
    int? currentPlayerIndex,
    int? currentRound,
    int? totalRounds,
    List<Map<String, dynamic>>? roundHistory,
    List<PlayerModel>? players,
    bool? isRoundActive,
    bool? isGameCompleted,
    bool? isLoading,
    int? wordsPerTurn,
  }) {
    return CharadesGameState(
      words: words ?? this.words,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      roundHistory: roundHistory ?? this.roundHistory,
      players: players ?? this.players,
      isRoundActive: isRoundActive ?? this.isRoundActive,
      isGameCompleted: isGameCompleted ?? this.isGameCompleted,
      isLoading: isLoading ?? this.isLoading,
      wordsPerTurn: wordsPerTurn ?? this.wordsPerTurn,
    );
  }
}

