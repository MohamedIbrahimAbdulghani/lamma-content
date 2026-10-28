// Lamma - by Mohamed Ibrahim

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/bootstrap_data.dart';
import '../models/player_model.dart';
import '../models/question_model.dart';
import '../storage/local_storage.dart';
import '../../net/server/room_server.dart';
import '../../net/client/room_client.dart';

// User Preferences
final currentPlayerNameProvider = StateProvider<String>((ref) => 'أحمد');
final currentPlayerAvatarProvider = StateProvider<String>((ref) => '🦁');

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before runApp');
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

  BootstrapNotifier(this._api, this._storage) : super(const AppBootstrapState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cachedData = _storage.getBootstrapData();

    try {
      final versionInfo = await _api.checkVersion();
      final serverVersion = versionInfo?['version'] as int? ?? 0;
      final cachedVersion = _storage.getCachedVersion();

      if (versionInfo != null && (serverVersion > cachedVersion || cachedData == null)) {
        final freshData = await _api.fetchBootstrap();
        if (freshData != null) {
          await _storage.saveBootstrapData(freshData);
          state = AppBootstrapState(
            isLoading: false,
            data: freshData,
            isOffline: false,
          );
          return;
        }
      }
    } catch (_) {}

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

final bootstrapProvider = StateNotifierProvider<BootstrapNotifier, AppBootstrapState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return BootstrapNotifier(api, storage);
});

// Game Types & Settings
enum GameType { spy, trivia, charades }

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
  SpySettingsNotifier() : super(const SpySettings());

  void update({
    int? rounds,
    int? discussionMinutes,
    int? votingSeconds,
    int? guessSeconds,
    int? spiesCount,
    String? wordPack,
  }) {
    state = state.copyWith(
      rounds: (rounds != null && rounds >= 1 && rounds <= 10) ? rounds : state.rounds,
      discussionMinutes: (discussionMinutes != null && discussionMinutes >= 1 && discussionMinutes <= 15)
          ? discussionMinutes
          : state.discussionMinutes,
      votingSeconds: (votingSeconds != null && votingSeconds >= 15 && votingSeconds <= 60)
          ? votingSeconds
          : state.votingSeconds,
      guessSeconds: (guessSeconds != null && guessSeconds >= 10 && guessSeconds <= 45)
          ? guessSeconds
          : state.guessSeconds,
      spiesCount: spiesCount ?? state.spiesCount,
      wordPack: wordPack ?? state.wordPack,
    );
  }
}

final spySettingsProvider = StateNotifierProvider<SpySettingsNotifier, SpySettings>((ref) {
  return SpySettingsNotifier();
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
    this.categories = const ['movies', 'sports', 'afeehat', 'history', 'general'],
  });

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
  TriviaSettingsNotifier() : super(const TriviaSettings());

  void update({
    int? questionsCount,
    int? timePerQuestion,
    String? difficulty,
    List<String>? categories,
  }) {
    state = state.copyWith(
      questionsCount: (questionsCount != null && questionsCount >= 5 && questionsCount <= 30)
          ? questionsCount
          : state.questionsCount,
      timePerQuestion: (timePerQuestion != null && timePerQuestion >= 5 && timePerQuestion <= 60)
          ? timePerQuestion
          : state.timePerQuestion,
      difficulty: difficulty ?? state.difficulty,
      categories: categories ?? state.categories,
    );
  }

  void toggleCategory(String cat) {
    final list = [...state.categories];
    if (list.contains(cat)) {
      if (list.length > 1) list.remove(cat);
    } else {
      list.add(cat);
    }
    state = state.copyWith(categories: list);
  }
}

final triviaSettingsProvider = StateNotifierProvider<TriviaSettingsNotifier, TriviaSettings>((ref) {
  return TriviaSettingsNotifier();
});

class CharadesSettings {
  final int roundSeconds;
  final int roundsPerPlayer;
  final String category; // movies, jobs, verbs, mixed

  const CharadesSettings({
    this.roundSeconds = 60,
    this.roundsPerPlayer = 2,
    this.category = 'movies',
  });

  CharadesSettings copyWith({
    int? roundSeconds,
    int? roundsPerPlayer,
    String? category,
  }) {
    return CharadesSettings(
      roundSeconds: roundSeconds ?? this.roundSeconds,
      roundsPerPlayer: roundsPerPlayer ?? this.roundsPerPlayer,
      category: category ?? this.category,
    );
  }
}

class CharadesSettingsNotifier extends StateNotifier<CharadesSettings> {
  CharadesSettingsNotifier() : super(const CharadesSettings());

  void update({
    int? roundSeconds,
    int? roundsPerPlayer,
    String? category,
  }) {
    state = state.copyWith(
      roundSeconds: (roundSeconds != null && roundSeconds >= 30 && roundSeconds <= 180)
          ? roundSeconds
          : state.roundSeconds,
      roundsPerPlayer: (roundsPerPlayer != null && roundsPerPlayer >= 1 && roundsPerPlayer <= 5)
          ? roundsPerPlayer
          : state.roundsPerPlayer,
      category: category ?? state.category,
    );
  }
}

final charadesSettingsProvider = StateNotifierProvider<CharadesSettingsNotifier, CharadesSettings>((ref) {
  return CharadesSettingsNotifier();
});

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
  final String secretWord;
  final String secretCategory;
  final QuestionModel? currentQuestion;
  final int questionNumber;
  final int totalQuestions;
  final String? strikeToast;
  final int myStrikes;
  final bool isKicked;
  final bool hostLeft;

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
    this.secretWord = 'خان الخليلي',
    this.secretCategory = 'أماكن',
    this.currentQuestion,
    this.questionNumber = 1,
    this.totalQuestions = 10,
    this.strikeToast,
    this.myStrikes = 0,
    this.isKicked = false,
    this.hostLeft = false,
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
    String? secretWord,
    String? secretCategory,
    QuestionModel? currentQuestion,
    int? questionNumber,
    int? totalQuestions,
    String? strikeToast,
    int? myStrikes,
    bool? isKicked,
    bool? hostLeft,
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
      secretWord: secretWord ?? this.secretWord,
      secretCategory: secretCategory ?? this.secretCategory,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      questionNumber: questionNumber ?? this.questionNumber,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      strikeToast: strikeToast,
      myStrikes: myStrikes ?? this.myStrikes,
      isKicked: isKicked ?? this.isKicked,
      hostLeft: hostLeft ?? this.hostLeft,
    );
  }
}

class RoomNotifier extends StateNotifier<ActiveRoomState> {
  RoomServer? _server;
  RoomClient? _client;

  RoomNotifier([GameType initialGame = GameType.spy])
      : super(ActiveRoomState(selectedGame: initialGame, gameMode: initialGame.name));

  void setHostServer(RoomServer server, String code, String ip) {
    _server = server;
    state = state.copyWith(
      isHost: true,
      roomCode: code,
      hostIp: ip,
      players: server.players,
    );
  }

  void setClient(RoomClient client, String code, String ip) {
    _client = client;
    state = state.copyWith(
      isHost: false,
      roomCode: code,
      hostIp: ip,
    );
  }

  void setSelectedGame(GameType game) {
    state = state.copyWith(selectedGame: game, gameMode: game.name);
    _server?.updateGameMode(game.name);
  }

  void startGame() {
    state = state.copyWith(currentPhase: 'in_game');
  }

  void updateFromNetwork(Map<String, dynamic> data) {
    final rawPlayers = data['players'] as List<dynamic>? ?? [];
    final playersList = rawPlayers
        .map((e) => PlayerModel.fromJson(e as Map<String, dynamic>))
        .toList();

    QuestionModel? q;
    if (data['current_question'] != null) {
      q = QuestionModel.fromJson(data['current_question'] as Map<String, dynamic>);
    }

    GameType? netGame;
    final netMode = data['game_mode'] as String?;
    if (netMode == 'spy') netGame = GameType.spy;
    if (netMode == 'trivia') netGame = GameType.trivia;
    if (netMode == 'charades') netGame = GameType.charades;

    state = state.copyWith(
      roomCode: data['room_code'] as String? ?? state.roomCode,
      selectedGame: netGame ?? state.selectedGame,
      gameMode: netMode ?? state.gameMode,
      currentPhase: data['current_phase'] as String? ?? state.currentPhase,
      timerSeconds: data['timer_seconds'] as int? ?? 0,
      players: playersList,
      secretCategory: data['secret_category'] as String? ?? '',
      currentQuestion: q,
      questionNumber: data['question_number'] as int? ?? state.questionNumber,
      totalQuestions: data['total_questions'] as int? ?? state.totalQuestions,
    );
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
  }

  void updatePlayerScore(String playerId, int points) {
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(score: p.score + points);
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated);
  }

  void leaveRoom() {
    _server?.stop();
    _client?.disconnect();
    _server = null;
    _client = null;
    state = ActiveRoomState(selectedGame: state.selectedGame, gameMode: state.gameMode);
  }

  RoomServer? get server => _server;
  RoomClient? get client => _client;
}

final roomProvider = StateNotifierProvider<RoomNotifier, ActiveRoomState>((ref) {
  final initialGame = ref.read(selectedGame);
  return RoomNotifier(initialGame);
});

final gameRoomProvider = roomProvider;
