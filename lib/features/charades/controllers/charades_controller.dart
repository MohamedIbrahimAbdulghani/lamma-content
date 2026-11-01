// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'charades_state.dart';

class CharadesGameNotifier extends StateNotifier<CharadesGameState> {
  final Ref ref;
  Timer? _timer;
  bool _isFetchingMore = false;

  CharadesGameNotifier(this.ref) : super(const CharadesGameState());

  /// بداية لعبة جديدة مع جلب كلمات بدون تكرار وتهيئة اللاعبين/الفرق
  Future<void> initGame({
    List<PlayerModel>? initialPlayers,
    int? roundSeconds,
    int? roundsPerPlayer,
    String? category,
    int? wordsPerTurn,
  }) async {
    _timer?.cancel();
    state = state.copyWith(isLoading: true);

    final settings = ref.read(charadesSettingsProvider);
    final bootstrap = ref.read(bootstrapProvider);
    final roomState = ref.read(gameRoomProvider);
    final contentService = ref.read(gameContentServiceProvider);

    final seconds = roundSeconds ?? settings.roundSeconds;
    final rounds = roundsPerPlayer ?? settings.roundsPerPlayer;
    final cat = category ?? settings.category;
    final wordsLimit = wordsPerTurn ?? settings.wordsPerTurn;

    // تجهيز قائمة اللاعبين / الفرق وتصفير السكور
    List<PlayerModel> playersList;
    if (initialPlayers != null && initialPlayers.isNotEmpty) {
      playersList = initialPlayers.map((p) => p.copyWith(score: 0)).toList();
    } else if (roomState.players.isNotEmpty) {
      playersList = roomState.players.map((p) => p.copyWith(score: 0)).toList();
    } else {
      playersList = [
        const PlayerModel(id: '1', name: 'الفريق الأول', emoji: '🦁', score: 0),
        const PlayerModel(
          id: '2',
          name: 'الفريق الثاني',
          emoji: '🦊',
          score: 0,
        ),
      ];
    }

    // جلب كلمات بدون تكرار عبر GameContentService (بحد أقصى أولي 30 كلمة لبدء سريع بدون تعليق)
    final neededWordsCount = (playersList.length * rounds * (wordsLimit > 0 ? wordsLimit : 10)).clamp(15, 30);
    final server = ref.read(gameRoomProvider.notifier).server;
    final pool = await contentService.getCharadesWords(
      count: neededWordsCount,
      category: cat,
      bootstrapData: bootstrap.data,
      externalSeenHashes: server?.getAllSeenCharadesHashes(),
    );

    state = CharadesGameState(
      words: pool,
      currentWordIndex: 0,
      secondsLeft: seconds,
      totalSeconds: seconds,
      currentPlayerIndex: 0,
      currentRound: 1,
      totalRounds: rounds,
      roundHistory: [],
      players: playersList,
      isRoundActive: false,
      isGameCompleted: false,
      isLoading: false,
      wordsPerTurn: wordsLimit,
    );

    ref.read(gameRoomProvider.notifier).setPlayers(playersList);
  }

  /// إعادة تشغيل اللعبة بكلمات جديدة وتصفير السكور
  Future<void> restartGame() async {
    await initGame(
      initialPlayers: state.players.map((p) => p.copyWith(score: 0)).toList(),
      roundSeconds: state.totalSeconds,
      roundsPerPlayer: state.totalRounds,
      wordsPerTurn: state.wordsPerTurn,
    );
  }

  /// تحديث قائمة الفرق / اللاعبين قبل بدء اللعب
  void setRegisteredPlayers(List<PlayerModel> players) {
    state = state.copyWith(players: players);
    ref.read(gameRoomProvider.notifier).setPlayers(players);
  }

  /// بدء تايمر الجولة الحالية
  void startRound() {
    _timer?.cancel();
    state = state.copyWith(
      secondsLeft: state.totalSeconds,
      roundHistory: [],
      isRoundActive: true,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsLeft > 1) {
        state = state.copyWith(secondsLeft: state.secondsLeft - 1);
      } else {
        timer.cancel();
        state = state.copyWith(secondsLeft: 0, isRoundActive: false);
      }
    });
  }

  /// جلب دفعة جديدة في الخلفية عند اقتراب انتهاء الرصيد دون أن يشعر اللاعب
  void _checkAndPrefetchMoreWords(int nextIndex) {
    final remainingWords = state.words.length - nextIndex;
    if (remainingWords <= 5 && !_isFetchingMore) {
      _isFetchingMore = true;
      Future.microtask(() async {
        try {
          final settings = ref.read(charadesSettingsProvider);
          final bootstrap = ref.read(bootstrapProvider);
          final contentService = ref.read(gameContentServiceProvider);

          final more = await contentService.getCharadesWords(
            count: 20,
            category: settings.category,
            bootstrapData: bootstrap.data,
          );

          if (!mounted) return;
          if (more.isNotEmpty) {
            final uniqueMore = more.where((w) => !state.words.contains(w)).toList();
            if (uniqueMore.isNotEmpty && mounted) {
              state = state.copyWith(words: [...state.words, ...uniqueMore]);
            }
          }
        } finally {
          _isFetchingMore = false;
        }
      });
    }
  }

  /// تسجيل الكلمة على أنها صحيحة (عرفوها ✅) وتحديث السكور فوراً بنقطة
  void markCorrect() {
    if (state.words.isEmpty) return;

    final word = state.currentWord;
    final history = List<Map<String, dynamic>>.from(state.roundHistory)
      ..add({'word': word, 'correct': true});

    // زيادة سكور اللاعب أو الفريق الحالي بنقطة فوراً
    final currentP = state.currentPlayer;
    List<PlayerModel> updatedPlayers = state.players;
    if (currentP != null) {
      updatedPlayers = state.players.map((p) {
        if (p.id == currentP.id) {
          return p.copyWith(score: p.score + 1);
        }
        return p;
      }).toList();
    }

    final nextIndex = state.currentWordIndex + 1;
    _checkAndPrefetchMoreWords(nextIndex);

    final limitReached = state.wordsPerTurn > 0 && history.length >= state.wordsPerTurn;
    if (limitReached) {
      _timer?.cancel();
    }

    state = state.copyWith(
      currentWordIndex: nextIndex,
      roundHistory: history,
      players: updatedPlayers,
      isRoundActive: !limitReached && state.isRoundActive,
    );

    ref.read(gameRoomProvider.notifier).setPlayers(updatedPlayers);
  }

  /// تسجيل الكلمة على أنها تخطي (تخطي ❌) بدون إضافة نقاط
  void markPass() {
    if (state.words.isEmpty) return;

    final word = state.currentWord;
    final history = List<Map<String, dynamic>>.from(state.roundHistory)
      ..add({'word': word, 'correct': false});

    final nextIndex = state.currentWordIndex + 1;
    _checkAndPrefetchMoreWords(nextIndex);

    final limitReached = state.wordsPerTurn > 0 && history.length >= state.wordsPerTurn;
    if (limitReached) {
      _timer?.cancel();
    }

    state = state.copyWith(
      currentWordIndex: nextIndex,
      roundHistory: history,
      isRoundActive: !limitReached && state.isRoundActive,
    );
  }

  /// الانتقال للاعب/الفريق التالي أو الجولة التالية أو إنهاء اللعبة
  bool advanceToNextTurn() {
    _timer?.cancel();

    final nextPlayerIdx = state.currentPlayerIndex + 1;

    if (nextPlayerIdx < state.players.length) {
      // لسه فيه لاعبين/فرق في نفس الجولة
      state = state.copyWith(
        currentPlayerIndex: nextPlayerIdx,
        secondsLeft: state.totalSeconds,
        roundHistory: [],
        isRoundActive: false,
      );
      return false;
    } else {
      // كل اللاعبين لعبوا الجولة الحالية
      final nextRound = state.currentRound + 1;
      if (nextRound <= state.totalRounds) {
        // بدء جولة جديدة
        state = state.copyWith(
          currentPlayerIndex: 0,
          currentRound: nextRound,
          secondsLeft: state.totalSeconds,
          roundHistory: [],
          isRoundActive: false,
        );
        return false;
      } else {
        // انتهت جميع الجولات
        state = state.copyWith(isGameCompleted: true, isRoundActive: false);
        return true;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final charadesGameProvider =
    StateNotifierProvider<CharadesGameNotifier, CharadesGameState>((ref) {
      return CharadesGameNotifier(ref);
    });
