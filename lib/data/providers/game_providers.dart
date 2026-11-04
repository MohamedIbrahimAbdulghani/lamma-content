import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../api/api_client.dart';
import '../models/bootstrap_data.dart';
import '../models/player_model.dart';
import '../models/question_model.dart';
import '../storage/local_storage.dart';
import '../services/game_content_service.dart';
import '../../features/spy/domain/spy_selector.dart';
import '../../net/server/room_server.dart';
import '../../net/client/room_client.dart';

// User Preferences
final currentPlayerNameProvider = StateProvider<String>((ref) => 'أحمد');
final currentPlayerAvatarProvider = StateProvider<String>((ref) => '🦁');

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized before runApp',
  );
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorage(prefs);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ApiClient(storage);
});

// App Bootstrap State
class AppBootstrapState {
  final bool isLoading;
  final BootstrapData? data;
  final String? errorMessage;
  final bool isOffline;

  const AppBootstrapState({
    this.isLoading = true,
    this.data,
    this.errorMessage,
    this.isOffline = false,
  });

  AppBootstrapState copyWith({
    bool? isLoading,
    BootstrapData? data,
    String? errorMessage,
    bool? isOffline,
  }) {
    return AppBootstrapState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class BootstrapNotifier extends StateNotifier<AppBootstrapState> {
  final ApiClient _api;
  final LocalStorage _storage;

  BootstrapNotifier(this._api, this._storage)
    : super(const AppBootstrapState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cachedData = _storage.getBootstrapData();

    try {
      final versionInfo = await _api.checkVersion();
      final serverVersion = versionInfo?['version'] as int? ?? 0;
      final cachedVersion = _storage.getCachedVersion();

      if (versionInfo != null &&
          (serverVersion > cachedVersion || cachedData == null)) {
        final freshData = await _api.fetchBootstrap();
        if (!mounted) return;
        if (freshData != null) {
          await _storage.saveBootstrapData(freshData);
          if (!mounted) return;
          state = AppBootstrapState(
            isLoading: false,
            data: freshData,
            isOffline: false,
          );
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    if (cachedData != null) {
      state = AppBootstrapState(
        isLoading: false,
        data: cachedData,
        isOffline: true,
      );
    } else {
      state = const AppBootstrapState(
        isLoading: false,
        data: null,
        errorMessage: 'محتاج تتصل بالنت مرة واحدة عشان تحمّل المحتوى',
        isOffline: true,
      );
    }
  }
}

final bootstrapProvider =
    StateNotifierProvider<BootstrapNotifier, AppBootstrapState>((ref) {
      final api = ref.watch(apiClientProvider);
      final storage = ref.watch(localStorageProvider);
      return BootstrapNotifier(api, storage);
    });

// Game Types & Settings
enum GameType { spy, trivia, charades }

extension GameTypeInfo on GameType {
  String get title {
    switch (this) {
      case GameType.spy:
        return 'مين الجاسوس';
      case GameType.trivia:
        return 'تحدي الشلة';
      case GameType.charades:
        return 'مثّل ومتتكلمش';
    }
  }

  String get shortDescription {
    switch (this) {
      case GameType.spy:
        return 'دوّر على الجاسوس بينكم';
      case GameType.trivia:
        return 'أسئلة وأفيهات وكورة';
      case GameType.charades:
        return 'تمثيل وتخمين من غير كلام';
    }
  }

  String get emoji {
    switch (this) {
      case GameType.spy:
        return '🕵️';
      case GameType.trivia:
        return '🎯';
      case GameType.charades:
        return '🎭';
    }
  }

  Color get accentColor {
    switch (this) {
      case GameType.spy:
        return AppTheme.accentCoral;
      case GameType.trivia:
        return AppTheme.accentSaffron;
      case GameType.charades:
        return AppTheme.accentMint;
    }
  }
}

final selectedGame = StateProvider<GameType>((ref) => GameType.spy);
final selectedGameProvider = selectedGame;

class SpySettings {
  final int rounds;
  final int discussionMinutes;
  final int votingSeconds;
  final int guessSeconds;
  final int spiesCount; // 0 = auto
  final String wordPack; // places, movies, food, mixed

  const SpySettings({
    this.rounds = 3,
    this.discussionMinutes = 5,
    this.votingSeconds = 30,
    this.guessSeconds = 15,
    this.spiesCount = 0,
    this.wordPack = 'places',
  });

  factory SpySettings.fromJson(Map<String, dynamic> json) {
    return SpySettings(
      rounds: json['rounds'] as int? ?? 3,
      discussionMinutes: json['discussionMinutes'] as int? ?? 5,
      votingSeconds: json['votingSeconds'] as int? ?? 30,
      guessSeconds: json['guessSeconds'] as int? ?? 15,
      spiesCount: json['spiesCount'] as int? ?? 0,
      wordPack: json['wordPack'] as String? ?? 'places',
    );
  }

  Map<String, dynamic> toJson() => {
    'rounds': rounds,
    'discussionMinutes': discussionMinutes,
    'votingSeconds': votingSeconds,
    'guessSeconds': guessSeconds,
    'spiesCount': spiesCount,
    'wordPack': wordPack,
  };

  SpySettings copyWith({
    int? rounds,
    int? discussionMinutes,
    int? votingSeconds,
    int? guessSeconds,
    int? spiesCount,
    String? wordPack,
  }) {
    return SpySettings(
      rounds: rounds ?? this.rounds,
      discussionMinutes: discussionMinutes ?? this.discussionMinutes,
      votingSeconds: votingSeconds ?? this.votingSeconds,
      guessSeconds: guessSeconds ?? this.guessSeconds,
      spiesCount: spiesCount ?? this.spiesCount,
      wordPack: wordPack ?? this.wordPack,
    );
  }
}

class SpySettingsNotifier extends StateNotifier<SpySettings> {
  final LocalStorage? _storage;

  SpySettingsNotifier([this._storage]) : super(_loadInitialSettings(_storage));

  static SpySettings _loadInitialSettings(LocalStorage? storage) {
    if (storage != null && storage.hasSpySettings()) {
      final saved = storage.getSavedSpySettings();
      if (saved != null) {
        return SpySettings.fromJson(saved);
      }
    }
    return const SpySettings();
  }

  Future<void> reset() async {
    state = const SpySettings();
    await _save();
  }

  Future<void> update({
    int? rounds,
    int? discussionMinutes,
    int? votingSeconds,
    int? guessSeconds,
    int? spiesCount,
    String? wordPack,
  }) async {
    state = state.copyWith(
      rounds: (rounds != null && rounds >= 1 && rounds <= 10)
          ? rounds
          : state.rounds,
      discussionMinutes:
          (discussionMinutes != null &&
              discussionMinutes >= 1 &&
              discussionMinutes <= 15)
          ? discussionMinutes
          : state.discussionMinutes,
      votingSeconds:
          (votingSeconds != null && votingSeconds >= 15 && votingSeconds <= 60)
          ? votingSeconds
          : state.votingSeconds,
      guessSeconds:
          (guessSeconds != null && guessSeconds >= 10 && guessSeconds <= 45)
          ? guessSeconds
          : state.guessSeconds,
      spiesCount: spiesCount ?? state.spiesCount,
      wordPack: wordPack ?? state.wordPack,
    );
    await _save();
  }

  Future<void> _save() async {
    await _storage?.saveSpySettingsData(
      rounds: state.rounds,
      discussionMinutes: state.discussionMinutes,
      votingSeconds: state.votingSeconds,
      guessSeconds: state.guessSeconds,
      spiesCount: state.spiesCount,
      wordPack: state.wordPack,
    );
  }
}

final spySettingsProvider =
    StateNotifierProvider<SpySettingsNotifier, SpySettings>((ref) {
      final storage = ref.watch(localStorageProvider);
      return SpySettingsNotifier(storage);
    });

class TriviaSettings {
  final int questionsCount;
  final int timePerQuestion;
  final String difficulty; // all, easy, medium, hard
  final List<String> categories;

  const TriviaSettings({
    this.questionsCount = 10,
    this.timePerQuestion = 15,
    this.difficulty = 'all',
    this.categories = const [
      'movies',
      'sports',
      'afeehat',
      'history',
      'general',
    ],
  });

  factory TriviaSettings.fromJson(Map<String, dynamic> json) {
    return TriviaSettings(
      questionsCount: json['questionsCount'] as int? ?? 10,
      timePerQuestion: json['timePerQuestion'] as int? ?? 15,
      difficulty: json['difficulty'] as String? ?? 'all',
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['movies', 'sports', 'afeehat', 'history', 'general'],
    );
  }

  Map<String, dynamic> toJson() => {
    'questionsCount': questionsCount,
    'timePerQuestion': timePerQuestion,
    'difficulty': difficulty,
    'categories': categories,
  };

  TriviaSettings copyWith({
    int? questionsCount,
    int? timePerQuestion,
    String? difficulty,
    List<String>? categories,
  }) {
    return TriviaSettings(
      questionsCount: questionsCount ?? this.questionsCount,
      timePerQuestion: timePerQuestion ?? this.timePerQuestion,
      difficulty: difficulty ?? this.difficulty,
      categories: categories ?? this.categories,
    );
  }
}

class TriviaSettingsNotifier extends StateNotifier<TriviaSettings> {
  final LocalStorage? _storage;

  TriviaSettingsNotifier([this._storage])
    : super(_loadInitialSettings(_storage));

  static TriviaSettings _loadInitialSettings(LocalStorage? storage) {
    if (storage != null && storage.hasTriviaSettings()) {
      final saved = storage.getSavedTriviaSettings();
      if (saved != null) {
        return TriviaSettings.fromJson(saved);
      }
    }
    return const TriviaSettings();
  }

  void reset() {
    state = const TriviaSettings();
    _save();
  }

  Future<void> update({
    int? questionsCount,
    int? timePerQuestion,
    String? difficulty,
    List<String>? categories,
  }) async {
    state = state.copyWith(
      questionsCount:
          (questionsCount != null &&
              questionsCount >= 5 &&
              questionsCount <= 30)
          ? questionsCount
          : state.questionsCount,
      timePerQuestion:
          (timePerQuestion != null &&
              timePerQuestion >= 5 &&
              timePerQuestion <= 60)
          ? timePerQuestion
          : state.timePerQuestion,
      difficulty: difficulty ?? state.difficulty,
      categories: categories ?? state.categories,
    );
    await _save();
  }

  Future<void> toggleCategory(String cat) async {
    final list = [...state.categories];
    if (list.contains(cat)) {
      if (list.length > 1) list.remove(cat);
    } else {
      list.add(cat);
    }
    state = state.copyWith(categories: list);
    await _save();
  }

  Future<void> _save() async {
    await _storage?.saveTriviaSettingsData(
      questionsCount: state.questionsCount,
      timePerQuestion: state.timePerQuestion,
      difficulty: state.difficulty,
      categories: state.categories,
    );
  }
}

final triviaSettingsProvider =
    StateNotifierProvider<TriviaSettingsNotifier, TriviaSettings>((ref) {
      final storage = ref.watch(localStorageProvider);
      return TriviaSettingsNotifier(storage);
    });

class CharadesSettings {
  final int roundSeconds;
  final int roundsPerPlayer;
  final String category; // movies, series, actions, jobs, animals, places, things, proverbs, mixed
  final int wordsPerTurn; // 0 = مفتوح, 5, 10, 15, 20, 30

  const CharadesSettings({
    this.roundSeconds = 60,
    this.roundsPerPlayer = 2,
    this.category = 'movies',
    this.wordsPerTurn = 10,
  });

  factory CharadesSettings.fromJson(Map<String, dynamic> json) {
    return CharadesSettings(
      roundSeconds: json['roundSeconds'] as int? ?? 60,
      roundsPerPlayer: json['roundsPerPlayer'] as int? ?? 2,
      category: json['category'] as String? ?? 'movies',
      wordsPerTurn: json['wordsPerTurn'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
    'roundSeconds': roundSeconds,
    'roundsPerPlayer': roundsPerPlayer,
    'category': category,
    'wordsPerTurn': wordsPerTurn,
  };

  CharadesSettings copyWith({
    int? roundSeconds,
    int? roundsPerPlayer,
    String? category,
    int? wordsPerTurn,
  }) {
    return CharadesSettings(
      roundSeconds: roundSeconds ?? this.roundSeconds,
      roundsPerPlayer: roundsPerPlayer ?? this.roundsPerPlayer,
      category: category ?? this.category,
      wordsPerTurn: wordsPerTurn ?? this.wordsPerTurn,
    );
  }
}

class CharadesSettingsNotifier extends StateNotifier<CharadesSettings> {
  final LocalStorage? _storage;

  CharadesSettingsNotifier([this._storage])
    : super(_loadInitialSettings(_storage));

  static CharadesSettings _loadInitialSettings(LocalStorage? storage) {
    if (storage != null && storage.hasCharadesSettings()) {
      final saved = storage.getSavedCharadesSettings();
      if (saved != null) {
        final cat = saved['category'] as String?;
        final normalizedCat = GameContentService.normalizeCharadesCategory(cat);
        return CharadesSettings.fromJson({...saved, 'category': normalizedCat});
      }
    }
    return const CharadesSettings();
  }

  Future<void> reset() async {
    state = const CharadesSettings();
    await _save();
  }

  Future<void> update({
    int? roundSeconds,
    int? roundsPerPlayer,
    String? category,
    int? wordsPerTurn,
  }) async {
    final normalizedCategory = category != null
        ? GameContentService.normalizeCharadesCategory(category)
        : state.category;

    state = state.copyWith(
      roundSeconds:
          (roundSeconds != null && roundSeconds >= 30 && roundSeconds <= 180)
          ? roundSeconds
          : state.roundSeconds,
      roundsPerPlayer:
          (roundsPerPlayer != null &&
              roundsPerPlayer >= 1 &&
              roundsPerPlayer <= 5)
          ? roundsPerPlayer
          : state.roundsPerPlayer,
      category: normalizedCategory,
      wordsPerTurn: wordsPerTurn != null && wordsPerTurn >= 0
          ? wordsPerTurn
          : state.wordsPerTurn,
    );
    await _save();
  }

  Future<void> _save() async {
    await _storage?.saveCharadesSettingsData(
      roundSeconds: state.roundSeconds,
      roundsPerPlayer: state.roundsPerPlayer,
      category: state.category,
      wordsPerTurn: state.wordsPerTurn,
    );
  }
}

final charadesSettingsProvider =
    StateNotifierProvider<CharadesSettingsNotifier, CharadesSettings>((ref) {
      final storage = ref.watch(localStorageProvider);
      return CharadesSettingsNotifier(storage);
    });

/// نتيجة التصويت على الجاسوس
enum SpyGameOutcome {
  none,
  citizensWin, // المواطنين كشفوا الجاسوس وهو مخمنش الكلمة صح
  spyWinsGuess, // الجاسوس اتكشف بس خمن الكلمة صح
  spyWinsHidden, // الجاسوس مكتشفوش - صوتوا على حد غلط
}

// Active Room State
class ActiveRoomState {
  final String roomCode;
  final String hostIp;
  final bool isHost;
  final GameType selectedGame;
  final String gameMode; // 'spy', 'trivia', 'charades'
  final String currentPhase;
  final int timerSeconds;
  final List<PlayerModel> players;
  final String myPlayerId;
  final List<String> spyPlayerIds;
  final List<String> previousSpyIds;
  final int currentRound;
  final int totalRounds;
  final bool isStartingRound;
  final String secretWord;
  final String secretCategory;
  final QuestionModel? currentQuestion;
  final List<QuestionModel> triviaQuestions;
  final int questionNumber;
  final int totalQuestions;
  final String? strikeToast;
  final int myStrikes;
  final bool isKicked;
  final bool hostLeft;
  // Spy game result fields
  final String? votedPlayerId; // اللاعب اللي اتصوت عليه
  final bool? spyGuessedCorrectly; // هل الجاسوس خمن الكلمة صح
  final String? spyGuessedWord; // الكلمة اللي خمنها الجاسوس
  final List<String> spyChoices; // خيارات الفرصة الأخيرة للجاسوس من نفس المجموعة
  final SpyGameOutcome spyOutcome; // النتيجة النهائية

  const ActiveRoomState({
    this.roomCode = '',
    this.hostIp = '',
    this.isHost = false,
    this.selectedGame = GameType.spy,
    this.gameMode = 'spy',
    this.currentPhase = 'lobby',
    this.timerSeconds = 0,
    this.players = const [],
    this.myPlayerId = '1',
    this.spyPlayerIds = const ['2'],
    this.previousSpyIds = const [],
    this.currentRound = 1,
    this.totalRounds = 3,
    this.isStartingRound = false,
    this.secretWord = 'خان الخليلي',
    this.secretCategory = 'أماكن',
    this.spyChoices = const [],
    this.currentQuestion,
    this.triviaQuestions = const [],
    this.questionNumber = 1,
    this.totalQuestions = 10,
    this.strikeToast,
    this.myStrikes = 0,
    this.isKicked = false,
    this.hostLeft = false,
    this.votedPlayerId,
    this.spyGuessedCorrectly,
    this.spyGuessedWord,
    this.spyOutcome = SpyGameOutcome.none,
  });

  ActiveRoomState copyWith({
    String? roomCode,
    String? hostIp,
    bool? isHost,
    GameType? selectedGame,
    String? gameMode,
    String? currentPhase,
    int? timerSeconds,
    List<PlayerModel>? players,
    String? myPlayerId,
    List<String>? spyPlayerIds,
    List<String>? previousSpyIds,
    int? currentRound,
    int? totalRounds,
    bool? isStartingRound,
    String? secretWord,
    String? secretCategory,
    List<String>? spyChoices,
    QuestionModel? currentQuestion,
    List<QuestionModel>? triviaQuestions,
    int? questionNumber,
    int? totalQuestions,
    String? strikeToast,
    int? myStrikes,
    bool? isKicked,
    bool? hostLeft,
    String? votedPlayerId,
    bool? spyGuessedCorrectly,
    String? spyGuessedWord,
    SpyGameOutcome? spyOutcome,
  }) {
    return ActiveRoomState(
      roomCode: roomCode ?? this.roomCode,
      hostIp: hostIp ?? this.hostIp,
      isHost: isHost ?? this.isHost,
      selectedGame: selectedGame ?? this.selectedGame,
      gameMode: gameMode ?? this.gameMode,
      currentPhase: currentPhase ?? this.currentPhase,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      players: players ?? this.players,
      myPlayerId: myPlayerId ?? this.myPlayerId,
      spyPlayerIds: spyPlayerIds ?? this.spyPlayerIds,
      previousSpyIds: previousSpyIds ?? this.previousSpyIds,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      isStartingRound: isStartingRound ?? this.isStartingRound,
      secretWord: secretWord ?? this.secretWord,
      secretCategory: secretCategory ?? this.secretCategory,
      spyChoices: spyChoices ?? this.spyChoices,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      triviaQuestions: triviaQuestions ?? this.triviaQuestions,
      questionNumber: questionNumber ?? this.questionNumber,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      strikeToast: strikeToast,
      myStrikes: myStrikes ?? this.myStrikes,
      isKicked: isKicked ?? this.isKicked,
      hostLeft: hostLeft ?? this.hostLeft,
      votedPlayerId: votedPlayerId ?? this.votedPlayerId,
      spyGuessedCorrectly: spyGuessedCorrectly ?? this.spyGuessedCorrectly,
      spyGuessedWord: spyGuessedWord ?? this.spyGuessedWord,
      spyOutcome: spyOutcome ?? this.spyOutcome,
    );
  }
}

class RoomNotifier extends StateNotifier<ActiveRoomState> {
  final Ref? _ref;
  RoomServer? _server;
  RoomClient? _client;

  RoomNotifier([this._ref, GameType initialGame = GameType.spy])
    : super(
        ActiveRoomState(selectedGame: initialGame, gameMode: initialGame.name),
      );

  void setHostServer(RoomServer server, String code, String ip) {
    _server = server;
    state = state.copyWith(
      isHost: true,
      roomCode: code,
      hostIp: ip,
      players: server.players,
      myPlayerId: server.hostPlayer.id,
    );
  }

  void setClient(RoomClient client, String code, String ip) {
    _client = client;
    state = state.copyWith(
      isHost: false,
      roomCode: code,
      hostIp: ip,
      myPlayerId: client.deviceId,
    );
  }

  void setSelectedGame(GameType game) {
    // منع تغيير نوع اللعبة أثناء اللعب الفعلي فقط، ويُسمح به في اللوبي
    if (state.currentPhase != 'lobby' && state.currentPhase.isNotEmpty) {
      return;
    }
    state = state.copyWith(selectedGame: game, gameMode: game.name);
    _server?.updateGameMode(game.name);
  }

  void startGame() {
    state = state.copyWith(currentPhase: 'in_game');
  }

  void resetStartingGuard() {
    state = state.copyWith(isStartingRound: false);
  }

  /// تهيئة جولة جديدة للعبة مين الجاسوس بدون تكرار الكلمات ومع تطبيق قواعد الجولات وعدالة اختيار الجاسوس
  Future<void> startSpyGameRound({
    required String packSlug,
    required BootstrapData? bootstrapData,
    int? totalRounds,
    bool isNewGame = false,
  }) async {
    // منع السباق وتعدد الاستدعاء السريع (Atomic guard)
    if (state.isStartingRound) return;

    final targetTotalRounds =
        totalRounds ??
        (_ref?.read(spySettingsProvider).rounds ?? state.totalRounds);

    // فحص عدد الجولات في منطق البدء نفسه: لا يمكن تجاوز الحد الأقصى للجولات
    if (!isNewGame && state.currentRound >= state.totalRounds) {
      return;
    }

    state = state.copyWith(isStartingRound: true);
    try {

    String? pickedWord;
    String categoryTitle = 'أماكن';
    if (packSlug == 'movies') {
      categoryTitle = 'أفلام';
    } else if (packSlug == 'food') {
      categoryTitle = 'أكلات';
    }

    List<String> spyChoices = [];

    // 0. الاستهلاك الفوري للتجهيز المسبق إن وجد (0ms)
    if (_ref != null && state.roomCode.isNotEmpty) {
      try {
        final contentService = _ref.read(gameContentServiceProvider);
        final prebuffered = contentService.consumePrebufferedSpyRound(state.roomCode);
        if (prebuffered != null && prebuffered['secret_word'] != null) {
          pickedWord = prebuffered['secret_word'] as String;
          categoryTitle = prebuffered['group_title_ar'] as String? ?? categoryTitle;
          spyChoices = (prebuffered['spy_choices'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    if (pickedWord == null && _ref != null && state.roomCode.isNotEmpty) {
      try {
        final api = _ref.read(apiClientProvider);
        final spyData = await api.fetchNextSpyRound(
          state.roomCode,
          pack: packSlug,
          previousWord: state.secretWord,
          seenWordHashes: _server?.getAllSeenSpyHashes().toList() ?? const [],
        );
        if (spyData != null && spyData['secret_word'] != null) {
          pickedWord = spyData['secret_word'] as String;
          categoryTitle = spyData['group_title_ar'] as String? ?? categoryTitle;
          spyChoices = (spyData['spy_choices'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    String? spyFailureReason;
    if (pickedWord == null && _ref != null) {
      try {
        final contentService = _ref.read(gameContentServiceProvider);
        pickedWord = await contentService.getNextSpyWord(
          packSlug: packSlug,
          bootstrapData: bootstrapData,
          previousWord: state.secretWord,
          externalSeenHashes: _server?.getAllSeenSpyHashes(),
        );
      } catch (e) {
        if (e is InsufficientSpyWordsException) {
          spyFailureReason = e.failureReason;
        }
      }
    }

    if (pickedWord == null) {
      // ممنوع التدوير الصامت للأقدم مشاهدة عند نفاد الكلمات
      throw InsufficientSpyWordsException(pack: packSlug, failureReason: spyFailureReason);
    }

    // تجهيز مسبق للجولات التالية في الخلفية بدون حجب
    if (_ref != null && state.roomCode.isNotEmpty) {
      final contentService = _ref.read(gameContentServiceProvider);
      unawaited(
        contentService.prebufferNextSpyGame(
          roomCode: state.roomCode,
          rounds: targetTotalRounds,
          packSlug: packSlug,
        ),
      );
    }

    // تسجيل الجولة فوراً كمشاهدة لدى جميع الحاضرين لحظة التقديم
    if (_ref != null) {
      final contentService = _ref.read(gameContentServiceProvider);
      await contentService.markSpyRoundPresented(
        pickedWord,
        spyChoices: spyChoices,
        roomServer: _server,
      );
    }

    // تجهيز قائمة اللاعبين
    List<PlayerModel> playersList = state.players;
    if (playersList.isEmpty) {
      playersList = [
        const PlayerModel(id: '1', name: 'أحمد', emoji: '🦁'),
        const PlayerModel(id: '2', name: 'سارة', emoji: '🦊'),
        const PlayerModel(id: '3', name: 'كريم', emoji: '🐻'),
        const PlayerModel(id: '4', name: 'نور', emoji: '🐼'),
      ];
    }

    final active = playersList.where((p) => !p.isKicked).toList();
    if (active.isEmpty) {
      state = state.copyWith(isStartingRound: false);
      return;
    }

    // 1. تحديد عدد الجواسيس المطلوب حسب الإعدادات وعدد اللاعبين
    final spiesSetting = _ref?.read(spySettingsProvider).spiesCount ?? 0;
    int neededSpies = 1;
    if (spiesSetting == 2) {
      neededSpies = active.length >= 4 ? 2 : 1;
    } else if (spiesSetting == 0) {
      neededSpies = active.length >= 6 ? 2 : 1;
    } else {
      neededSpies = 1;
    }

    // 2. تطبيق قاعدة منع التكرار مع احتمال الاستثناء (3%) واختيار الجواسيس
    final chosenSpyIds = SpySelector.selectSpyIds(
      activePlayers: active,
      previousSpyIds: state.previousSpyIds,
      neededSpies: neededSpies,
    );

    final updatedPlayers = playersList.map((p) {
      final base = isNewGame ? p.copyWith(score: 0) : p;
      if (chosenSpyIds.contains(p.id)) {
        return base.copyWith(role: 'spy', currentWord: null);
      } else {
        return base.copyWith(role: 'citizen', currentWord: pickedWord);
      }
    }).toList();

    final nextRoundNumber = isNewGame ? 1 : state.currentRound + 1;

    state = state.copyWith(
      currentRound: nextRoundNumber,
      totalRounds: targetTotalRounds,
      previousSpyIds: chosenSpyIds,
      secretWord: pickedWord,
      secretCategory: categoryTitle,
      spyChoices: spyChoices,
      spyPlayerIds: chosenSpyIds,
      players: updatedPlayers,
      votedPlayerId: null,
      spyGuessedCorrectly: null,
      spyGuessedWord: null,
      spyOutcome: SpyGameOutcome.none,
      currentPhase: 'role_hidden',
      isStartingRound: false,
    );

    _server?.startSpyGame(
      secretWord: pickedWord,
      categoryName: categoryTitle,
      discussionMinutes: _ref?.read(spySettingsProvider).discussionMinutes ?? 5,
      spyPlayerIds: chosenSpyIds,
      spyChoices: spyChoices,
      currentRound: nextRoundNumber,
      totalRounds: targetTotalRounds,
    );
    } finally {
      state = state.copyWith(isStartingRound: false);
    }
  }

  /// تهيئة جولة جديدة لتحدي الشلة وتوزيع الأسئلة على الجميع
  void startTriviaGameRound({
    required List<QuestionModel> questions,
    required int timePerQuestion,
  }) {
    state = state.copyWith(
      selectedGame: GameType.trivia,
      gameMode: 'trivia',
      currentPhase: 'trivia_question',
      triviaQuestions: questions,
      currentQuestion: questions.isNotEmpty ? questions.first : null,
      questionNumber: 1,
      totalQuestions: questions.length,
      timerSeconds: timePerQuestion,
    );
    _server?.startTriviaGame(questions, timePerQuestion: timePerQuestion);
  }

  /// تهيئة وبدء لعبة مثّل ومتتكلمش عبر الشبكة وإشعار المتفرجين
  void startCharadesGameRound({
    int? roundSeconds,
    String? activePlayerName,
    int? wordsPerTurn,
  }) {
    state = state.copyWith(
      selectedGame: GameType.charades,
      gameMode: 'charades',
      currentPhase: 'charades_play',
      timerSeconds: roundSeconds ?? 60,
    );
    _server?.startCharadesGame(
      roundSeconds: roundSeconds ?? 60,
      activePlayerName: activePlayerName,
      wordsPerTurn: wordsPerTurn ?? 10,
    );
  }

  void updateFromNetwork(Map<String, dynamic> data) {
    final rawPlayers = data['players'] as List<dynamic>? ?? [];
    final playersList = rawPlayers
        .map((e) => PlayerModel.fromJson(e as Map<String, dynamic>))
        .toList();

    QuestionModel? q;
    if (data['current_question'] != null) {
      q = QuestionModel.fromJson(
        data['current_question'] as Map<String, dynamic>,
      );
    }

    GameType? netGame;
    final netMode = data['game_mode'] as String?;
    if (netMode == 'spy') netGame = GameType.spy;
    if (netMode == 'trivia') netGame = GameType.trivia;
    if (netMode == 'charades') netGame = GameType.charades;

    List<QuestionModel> netQuestions = state.triviaQuestions;
    if (data['trivia_questions'] != null) {
      final rawList = data['trivia_questions'] as List<dynamic>? ?? [];
      netQuestions = rawList
          .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<String> netSpyChoices = state.spyChoices;
    if (data['spy_choices'] != null) {
      final rawChoices = data['spy_choices'] as List<dynamic>? ?? [];
      netSpyChoices = rawChoices.map((e) => e.toString()).toList();
    }

    state = state.copyWith(
      roomCode: data['room_code'] as String? ?? state.roomCode,
      selectedGame: netGame ?? state.selectedGame,
      gameMode: netMode ?? state.gameMode,
      currentPhase: data['current_phase'] as String? ?? state.currentPhase,
      timerSeconds: data['timer_seconds'] as int? ?? 0,
      players: playersList,
      secretWord: data['secret_word'] as String? ?? state.secretWord,
      secretCategory: data['secret_category'] as String? ?? '',
      spyChoices: netSpyChoices,
      currentRound: data['current_round'] as int? ?? state.currentRound,
      totalRounds: data['total_rounds'] as int? ?? state.totalRounds,
      currentQuestion: q,
      triviaQuestions: netQuestions,
      questionNumber: data['question_number'] as int? ?? state.questionNumber,
      totalQuestions: data['total_questions'] as int? ?? state.totalQuestions,
    );

    // مزامنة إعدادات اللعبة (مثل عدد الكلمات في الدور) مع باقي اللاعبين
    if (data['settings'] != null) {
      final netSettings = data['settings'] as Map<String, dynamic>;
      final charadesMap = netSettings['charades'] as Map<String, dynamic>?;
      final wpt = charadesMap != null
          ? (charadesMap['wordsPerTurn'] as int?)
          : (netSettings['words_per_turn'] as int?);
      final rSec = charadesMap != null
          ? (charadesMap['roundSeconds'] as int?)
          : (netSettings['round_seconds'] as int?);
      final cat = charadesMap != null
          ? (charadesMap['category'] as String?)
          : (netSettings['category'] as String?);
      if (wpt != null || rSec != null || cat != null) {
        _ref?.read(charadesSettingsProvider.notifier).update(
          wordsPerTurn: wpt,
          roundSeconds: rSec,
          category: cat,
        );
      }
    }
  }

  void showStrikeToast(String message) {
    state = state.copyWith(strikeToast: message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) state = state.copyWith(strikeToast: null);
    });
  }

  void setKicked() {
    state = state.copyWith(isKicked: true);
  }

  void setHostLeft() {
    state = state.copyWith(hostLeft: true);
  }

  void updatePhase(String phase) {
    state = state.copyWith(currentPhase: phase);
  }

  void setPlayers(List<PlayerModel> players) {
    state = state.copyWith(players: players);
    _server?.setPlayers(players);
  }

  void updatePlayerScore(String playerId, int points) {
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(score: p.score + points);
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated);
    _server?.setPlayers(updated);
  }

  /// بنسجل نتيجة التصويت (مين اتصوت عليه)
  void setVotedPlayer(String playerId) {
    final isSpy = state.spyPlayerIds.contains(playerId);
    final outcome = isSpy ? SpyGameOutcome.none : SpyGameOutcome.spyWinsHidden;

    List<PlayerModel> updatedPlayers = state.players;
    if (outcome == SpyGameOutcome.spyWinsHidden) {
      // الجاسوس كسب لأنهم اتهموا حد تاني - بياخد 200 نقطة
      updatedPlayers = state.players.map((p) {
        if (state.spyPlayerIds.contains(p.id)) {
          return p.copyWith(score: p.score + 200);
        }
        return p;
      }).toList();
    }

    state = state.copyWith(
      votedPlayerId: playerId,
      spyOutcome: outcome,
      players: updatedPlayers,
    );
  }

  /// بنسجل نتيجة تخمين الجاسوس للكلمة ونحدث النقط
  void setSpyGuessResult({
    required bool spyGuessedCorrectly,
    String? guessedWord,
  }) {
    SpyGameOutcome outcome;
    List<PlayerModel> updatedPlayers = state.players;

    if (spyGuessedCorrectly) {
      // الجاسوس اتكشف بس خمن الكلمة صح! بياخد 200 نقطة
      outcome = SpyGameOutcome.spyWinsGuess;
      updatedPlayers = state.players.map((p) {
        if (state.spyPlayerIds.contains(p.id)) {
          return p.copyWith(score: p.score + 200);
        }
        return p;
      }).toList();
    } else {
      // المواطنين كسبوا! كل مواطن بياخد 100 نقطة
      outcome = SpyGameOutcome.citizensWin;
      updatedPlayers = state.players.map((p) {
        if (!state.spyPlayerIds.contains(p.id)) {
          return p.copyWith(score: p.score + 100);
        }
        return p;
      }).toList();
    }

    state = state.copyWith(
      spyGuessedCorrectly: spyGuessedCorrectly,
      spyGuessedWord: guessedWord,
      spyOutcome: outcome,
      players: updatedPlayers,
    );
  }

  /// بنعمل reset لبيانات الجاسوس عشان الجولة الجديدة مع الحفاظ على جاسوس الجولة السابقة
  void resetSpyRound() {
    final prevSpies = state.previousSpyIds.isNotEmpty
        ? state.previousSpyIds
        : state.spyPlayerIds;
    state = ActiveRoomState(
      roomCode: state.roomCode,
      hostIp: state.hostIp,
      isHost: state.isHost,
      selectedGame: state.selectedGame,
      gameMode: state.gameMode,
      currentPhase: 'lobby',
      currentRound: 1,
      totalRounds: state.totalRounds,
      previousSpyIds: prevSpies,
      players: state.players
          .map((p) => p.copyWith(score: 0, role: null, currentWord: null))
          .toList(),
      myPlayerId: state.myPlayerId,
    );
  }

  /// المضيف: إلغاء الجولة الحالية فوراً وبلا نقاط والعودة لحالة اللوبي عند الجميع
  void hostReturnToLobby() {
    if (!state.isHost) return;
    _server?.returnToLobby();
    state = state.copyWith(
      currentPhase: 'lobby',
      timerSeconds: 0,
      currentQuestion: null,
      triviaQuestions: [],
      secretWord: '',
      secretCategory: '',
      spyChoices: [],
      votedPlayerId: null,
      spyOutcome: SpyGameOutcome.none,
      isStartingRound: false,
      players: state.players
          .map((p) => p.copyWith(role: null, currentWord: null))
          .toList(),
    );
  }

  /// اللاعب العادي: مغادرة الغرفة وإشعار الخادم وتحديث القائمة عند الجميع
  Future<void> playerLeaveRoom() async {
    if (state.isHost) {
      await _server?.stop();
      _server = null;
    } else {
      _client?.leaveRoom();
      _client = null;
    }
    state = ActiveRoomState(
      selectedGame: state.selectedGame,
      gameMode: state.gameMode,
    );
  }

  void leaveRoom() {
    _server?.stop();
    _client?.disconnect();
    _server = null;
    _client = null;
    state = ActiveRoomState(
      selectedGame: state.selectedGame,
      gameMode: state.gameMode,
    );
  }

  RoomServer? get server => _server;
  RoomClient? get client => _client;
}

final roomProvider = StateNotifierProvider<RoomNotifier, ActiveRoomState>((
  ref,
) {
  final initialGame = ref.read(selectedGame);
  return RoomNotifier(ref, initialGame);
});

final gameRoomProvider = roomProvider;
