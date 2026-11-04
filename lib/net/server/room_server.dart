// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../../data/models/player_model.dart';
import '../../data/models/question_model.dart';
import '../../features/spy/domain/spy_selector.dart';
import '../../features/trivia/domain/trivia_scorer.dart';
import '../protocol/game_message.dart';

class RoomServer {
  final String roomCode;
  final PlayerModel hostPlayer;
  final int port;
  final int udpPort;
  final Function(Map<String, dynamic> state) onStateChanged;
  final Function(String message) onStrikeToast;

  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  final Map<String, WebSocket> _clients = {};
  final List<PlayerModel> _players = [];
  bool _isClosed = false;

  String _gameMode = 'spy'; // 'spy', 'trivia', 'charades'
  String _currentPhase = 'lobby'; // 'lobby', 'role_hidden', 'discussion', 'voting', 'result', etc.
  int _timerSeconds = 0;
  Timer? _gameTimer;

  // Game Settings & State
  Map<String, dynamic> _gameSettings = {};
  List<QuestionModel> _triviaQuestions = [];
  int _triviaTimePerQuestion = 15;
  int _currentTriviaIndex = 0;
  String _secretWord = '';
  String _secretCategory = '';
  List<String> _spyChoices = [];
  List<String> _spyPlayerIds = [];
  List<String> _previousSpyIds = [];
  int _currentRound = 1;
  int _totalRounds = 3;
  final Map<String, int> _votes = {}; // voterId -> targetPlayerId
  final Map<String, int> _answers = {}; // playerId -> chosenIndex
  final Map<String, int> _answerTimes = {}; // playerId -> responseTimeMs

  // سجل بصمات اللاعبين الحاضرين لمنع التكرار في اللعب الجماعي
  final Map<String, Set<String>> _playerSeenTriviaPrompts = {};
  final Map<String, Set<String>> _playerSeenTriviaAnswers = {};
  final Map<String, Set<String>> _playerSeenSpyWords = {};
  final Map<String, Set<String>> _playerSeenCharadesWords = {};

  RoomServer({
    required this.roomCode,
    required this.hostPlayer,
    this.port = 8080,
    this.udpPort = 8082,
    required this.onStateChanged,
    required this.onStrikeToast,
  }) {
    // نتأكد إن المضيف مسجل كمضيف أول مع تهيئة مجموعات بصماته
    _players.add(hostPlayer.copyWith(isHost: true));
    _playerSeenTriviaPrompts[hostPlayer.id] = <String>{};
    _playerSeenTriviaAnswers[hostPlayer.id] = <String>{};
    _playerSeenSpyWords[hostPlayer.id] = <String>{};
    _playerSeenCharadesWords[hostPlayer.id] = <String>{};
  }

  List<PlayerModel> get players => List.unmodifiable(_players);
  String get gameMode => _gameMode;
  String get currentPhase => _currentPhase;
  bool get isClosed => _isClosed;

  Set<String> getAllSeenTriviaPromptHashes() {
    final all = <String>{};
    for (final s in _playerSeenTriviaPrompts.values) {
      all.addAll(s);
    }
    return all;
  }

  Set<String> getAllSeenTriviaAnswerHashes() {
    final all = <String>{};
    for (final s in _playerSeenTriviaAnswers.values) {
      all.addAll(s);
    }
    return all;
  }

  Set<String> getAllSeenSpyHashes() {
    final all = <String>{};
    for (final s in _playerSeenSpyWords.values) {
      all.addAll(s);
    }
    return all;
  }

  Set<String> getAllSeenCharadesHashes() {
    final all = <String>{};
    for (final s in _playerSeenCharadesWords.values) {
      all.addAll(s);
    }
    return all;
  }

  void setHostSeenHashes({
    Set<String> triviaPrompts = const {},
    Set<String> triviaAnswers = const {},
    Set<String> spyWords = const {},
    Set<String> charadesWords = const {},
  }) {
    _playerSeenTriviaPrompts[hostPlayer.id] = Set.from(triviaPrompts);
    _playerSeenTriviaAnswers[hostPlayer.id] = Set.from(triviaAnswers);
    _playerSeenSpyWords[hostPlayer.id] = Set.from(spyWords);
    _playerSeenCharadesWords[hostPlayer.id] = Set.from(charadesWords);
  }

  void recordSeenTriviaAcrossRoom(List<String> promptHashes, List<String> answerHashes) {
    for (final set in _playerSeenTriviaPrompts.values) {
      set.addAll(promptHashes);
    }
    for (final set in _playerSeenTriviaAnswers.values) {
      set.addAll(answerHashes);
    }
  }

  void recordSeenSpyAcrossRoom(String wordHash) {
    for (final set in _playerSeenSpyWords.values) {
      set.add(wordHash);
    }
  }

  void recordSeenCharadesAcrossRoom(List<String> hashes) {
    for (final set in _playerSeenCharadesWords.values) {
      set.addAll(hashes);
    }
  }


  Future<void> start() async {
    try {
      _isClosed = false;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen(_handleHttpRequest);

      // هنا بنبدأ مستمع UDP لاكتشاف الغرف تلقائياً عبر الشبكة المحلية
      _startUdpDiscoveryResponder();

      try {
        await WakelockPlus.enable();
      } catch (_) {}

      _broadcastState();
    } catch (e) {
      debugPrint('Error starting RoomServer: $e');
    }
  }

  /// مستمع الـ UDP للرد على استفسارات الأجهزة التانية بكود الغرفة
  Future<void> _startUdpDiscoveryResponder() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram == null) return;

          try {
            final text = utf8.decode(datagram.data);
            final json = jsonDecode(text) as Map<String, dynamic>;

            if (json['type'] == 'discover_room') {
              final queryCode = json['room_code']?.toString().trim() ?? '';
              // نتحقق إن الكود مطابق والغرفة لسه شغالة
              if (queryCode == roomCode && !_isClosed) {
                final responsePayload = jsonEncode({
                  'type': 'room_discovered',
                  'room_code': roomCode,
                  'game_mode': _gameMode,
                  'current_phase': _currentPhase,
                  'port': 8080,
                  'players_count': _players.length,
                });
                _udpSocket?.send(
                  utf8.encode(responsePayload),
                  datagram.address,
                  datagram.port,
                );
              }
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Could not bind UDP discovery socket: $e');
    }
  }

  Future<void> stop() async {
    _isClosed = true;
    _gameTimer?.cancel();
    _broadcastMessage(const GameMessage(type: 'host_left'));

    final socketsToClose = _clients.values.toList();
    for (final ws in socketsToClose) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();

    _udpSocket?.close();
    _udpSocket = null;

    await _server?.close(force: true);
    _server = null;

    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((ws) {
        _handleClientConnection(ws);
      });
    } else if (request.uri.path == '/lamma_probe') {
      // فحص سريع للغرفة عبر HTTP
      final queryCode = request.uri.queryParameters['code'] ?? '';
      final isMatch = queryCode.isEmpty || queryCode == roomCode;

      request.response
        ..statusCode = isMatch ? HttpStatus.ok : HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'room_code': roomCode,
          'game_mode': _gameMode,
          'current_phase': _currentPhase,
          'is_closed': _isClosed,
          'players_count': _players.length,
          'max_players': 10,
        }))
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('Lamma Room Server Active')
        ..close();
    }
  }

  void _handleClientConnection(WebSocket ws) {
    String? clientId;

    ws.listen(
      (data) {
        final message = GameMessage.deserialize(data);
        if (message == null) return;

        switch (message.type) {
          case 'join':
            if (_isClosed) {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'room_closed', 'message': 'هذه الغرفة مغلقة أو انتهت'},
              ).serialize());
              ws.close();
              return;
            }

            final reqCode = (message.payload['room_code'] as String? ?? '').trim();
            final name = (message.payload['name'] as String? ?? 'لاعب').trim();
            final emoji = message.payload['emoji'] as String? ?? '🦁';
            final deviceId = (message.payload['device_id'] as String? ?? '').trim();

            // 1. التحقق من كود الغرفة
            if (reqCode != roomCode) {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'wrong_code', 'message': 'كود الغرفة غير صحيح'},
              ).serialize());
              ws.close();
              return;
            }

            final validId = deviceId.isNotEmpty ? deviceId : const Uuid().v4();
            final existingPlayerIndex = _players.indexWhere((p) => p.id == validId);
            final isReconnecting = existingPlayerIndex != -1;

            // 2. التحقق من حالة اللعبة لو اللاعب جديد مش إعادة اتصال
            if (!isReconnecting && _currentPhase != 'lobby') {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'game_started', 'message': 'بدأت اللعبة بالفعل ولا يمكن الانضمام الآن'},
              ).serialize());
              ws.close();
              return;
            }

            // 3. التحقق الذري من الحد الأقصى للاعبين (10 كحد أقصى)
            if (!isReconnecting && _players.length >= 10) {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'room_full', 'message': 'الغرفة مكتملة (الحد الأقصى 10 لاعبين)'},
              ).serialize());
              ws.close();
              return;
            }

            clientId = validId;
            _clients[validId] = ws;

            // حفظ بصمات اللاعب المنضم لمنع تكرار ما شاهده سابقاً
            final triviaPrompts = (message.payload['seen_trivia'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                {};
            final triviaAnswers = (message.payload['seen_trivia_answers'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                {};
            final spyHashes = (message.payload['seen_spy'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                {};
            final charadesHashes = (message.payload['seen_charades'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                {};

            _playerSeenTriviaPrompts[validId] = triviaPrompts;
            _playerSeenTriviaAnswers[validId] = triviaAnswers;
            _playerSeenSpyWords[validId] = spyHashes;
            _playerSeenCharadesWords[validId] = charadesHashes;

            // 4. إضافة أو تحديث اللاعب (مع تثبيت المضيف ومنع ترقية المنضم لمضيف أبداً)
            if (isReconnecting) {
              final old = _players[existingPlayerIndex];
              _players[existingPlayerIndex] = old.copyWith(
                name: name.isNotEmpty ? name : old.name,
                emoji: emoji,
                isHost: old.isHost, // المضيف يظل مضيف، والمنضم يظل غير مضيف
              );
            } else {
              final newPlayer = PlayerModel(
                id: validId,
                name: name,
                emoji: emoji,
                isHost: false, // دائماً غير مضيف
              );
              _players.add(newPlayer);
            }

            // إرسال تأكيد الانضمام مع كامل حالة الغرفة
            ws.add(GameMessage(
              type: 'join_ack',
              payload: {
                'room_code': roomCode,
                'game_mode': _gameMode,
                'current_phase': _currentPhase,
                'players': _players.map((p) => p.toJson()).toList(),
                'settings': _gameSettings,
                'current_round': _currentRound,
                'total_rounds': _totalRounds,
              },
            ).serialize());

            // إرسال تحديث فوري لجميع اللاعبين والمضيف باللاعب الجديد
            _broadcastState();
            break;

          case 'intent':
            final action = message.payload['action'] as String? ?? '';
            _handlePlayerIntent(message.senderId ?? clientId ?? '', action, message.payload);
            break;

          case 'heartbeat':
            // keep-alive ack
            break;

          case 'leave_room':
            final id = clientId;
            if (id != null) {
              removePlayer(id);
            }
            break;
        }
      },
      onDone: () {
        final id = clientId;
        if (id != null) {
          removePlayer(id);
        }
      },
      onError: (_) {
        final id = clientId;
        if (id != null) {
          removePlayer(id);
        }
      },
    );
  }

  /// إزالة لاعب عند مغادرته الغرفة وإبلاغ الجميع، مع فحص الحد الأدنى للاعبين
  void removePlayer(String playerId) {
    _clients.remove(playerId);
    _players.removeWhere((p) => p.id == playerId && !p.isHost);
    _playerSeenTriviaPrompts.remove(playerId);
    _playerSeenTriviaAnswers.remove(playerId);
    _playerSeenSpyWords.remove(playerId);
    _playerSeenCharadesWords.remove(playerId);

    // التحقق أثناء اللعب: إذا أصبح عدد اللاعبين النشطين غير كافٍ لقاعدة اللعبة
    if (_currentPhase != 'lobby') {
      final active = _players.where((p) => !p.isKicked).toList();
      final minRequired = _gameMode == 'spy' ? 3 : 2;
      if (active.length < minRequired) {
        returnToLobby();
        return;
      }
    }

    _broadcastState();
  }

  /// إلغاء الجولة والعودة للوبي فوراً مع إلغاء المؤقتات وبث الحالة للجميع
  void returnToLobby() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _currentPhase = 'lobby';
    _timerSeconds = 0;
    _votes.clear();
    _answers.clear();
    _answerTimes.clear();

    // تصفير الأدوار والكلمات الحالية للجولة الملغاة مع الاحتفاظ باللاعبين
    for (int i = 0; i < _players.length; i++) {
      _players[i] = _players[i].copyWith(
        role: null,
        currentWord: null,
      );
    }

    _broadcastState();
  }

  void _handlePlayerIntent(String playerId, String action, Map<String, dynamic> payload) {
    switch (action) {
      case 'violation':
        // Anti-cheat strike detection
        final index = _players.indexWhere((p) => p.id == playerId);
        if (index != -1) {
          final p = _players[index];
          final newStrikes = p.strikes + 1;
          final isKicked = newStrikes >= 3;

          _players[index] = p.copyWith(strikes: newStrikes, isKicked: isKicked);
          final strikeMsg = '${p.name} خرج من اللعبة ($newStrikes/3)';
          onStrikeToast(strikeMsg);

          _broadcastMessage(GameMessage(
            type: 'strike_broadcast',
            payload: {
              'player_id': playerId,
              'player_name': p.name,
              'strikes': newStrikes,
              'is_kicked': isKicked,
              'message': strikeMsg,
            },
          ));

          _broadcastState();
        }
        break;

      case 'vote':
        final targetId = payload['target_id'] as String? ?? '';
        _votes[playerId] = targetId.hashCode;
        _broadcastState();
        break;

      case 'answer':
        final answerIdx = payload['answer_index'] as int? ?? -1;
        final remainingSec = payload['remaining_seconds'] as int? ?? _timerSeconds;
        _answers[playerId] = answerIdx;
        _answerTimes[playerId] = remainingSec;
        _broadcastState();

        final activePlayers = _players.where((p) => !p.isKicked).toList();
        if (_answers.length >= activePlayers.length) {
          _gameTimer?.cancel();
          _evaluateTriviaRound();
        }
        break;
    }
  }

  void setPlayers(List<PlayerModel> players) {
    _players.clear();
    _players.addAll(players);
    _broadcastState();
  }

  void updateGameMode(String mode) {
    _gameMode = mode;
    _broadcastState();
  }

  void updateSettings(Map<String, dynamic> settings) {
    _gameSettings = settings;
    _broadcastState();
  }

  void startSpyGame({
    required String secretWord,
    required String categoryName,
    required int discussionMinutes,
    List<String>? spyPlayerIds,
    List<String>? spyChoices,
    int? currentRound,
    int? totalRounds,
  }) {
    _secretWord = secretWord;
    _secretCategory = categoryName;
    _spyChoices = spyChoices ?? [];

    // تسجيل بصمة الكلمة والخيارات في سجلات جميع اللاعبين الحاضرين
    final spyWordHash = ArabicTextNormalizer.wordHash(secretWord);
    if (spyWordHash.isNotEmpty) {
      for (final set in _playerSeenSpyWords.values) {
        set.add(spyWordHash);
      }
    }
    for (final choice in _spyChoices) {
      final chHash = ArabicTextNormalizer.wordHash(choice);
      if (chHash.isNotEmpty) {
        for (final set in _playerSeenSpyWords.values) {
          set.add(chHash);
        }
      }
    }
    _gameMode = 'spy';
    _currentPhase = 'role_hidden';
    _votes.clear();
    if (currentRound != null) _currentRound = currentRound;
    if (totalRounds != null) _totalRounds = totalRounds;

    final activePlayers = _players.where((p) => !p.isKicked).toList();
    if (activePlayers.isEmpty) return;

    if (spyPlayerIds != null && spyPlayerIds.isNotEmpty) {
      _spyPlayerIds = spyPlayerIds;
    } else {
      _spyPlayerIds = SpySelector.selectSpyIds(
        activePlayers: activePlayers,
        previousSpyIds: _previousSpyIds,
        neededSpies: 1,
      );
    }
    _previousSpyIds = List.from(_spyPlayerIds);

    for (int i = 0; i < _players.length; i++) {
      final p = _players[i];
      if (_spyPlayerIds.contains(p.id)) {
        _players[i] = p.copyWith(role: 'spy', currentWord: null);
      } else {
        _players[i] = p.copyWith(role: 'citizen', currentWord: secretWord);
      }
    }

    _broadcastState();
  }

  void startDiscussionTimer(int minutes) {
    _currentPhase = 'discussion';
    _timerSeconds = minutes * 60;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        _timerSeconds--;
        _broadcastState();
      } else {
        timer.cancel();
        _currentPhase = 'voting';
        _timerSeconds = 30; // 30s voting
        _broadcastState();
      }
    });
    _broadcastState();
  }

  void startTriviaGame(List<QuestionModel> questions, {int timePerQuestion = 15}) {
    _triviaQuestions = questions;
    _triviaTimePerQuestion = timePerQuestion;
    _gameSettings['time_per_question'] = timePerQuestion;
    _currentTriviaIndex = 0;
    _gameMode = 'trivia';
    _answers.clear();
    _answerTimes.clear();
    _showNextTriviaQuestion();
  }

  void startCharadesGame({
    int roundSeconds = 60,
    String? activePlayerName,
    int wordsPerTurn = 10,
  }) {
    _gameMode = 'charades';
    _currentPhase = 'charades_play';
    _timerSeconds = roundSeconds;
    _gameSettings['words_per_turn'] = wordsPerTurn;
    _broadcastState();
  }

  void _showNextTriviaQuestion() {
    if (_currentTriviaIndex >= _triviaQuestions.length) {
      _currentPhase = 'final_results';
      _broadcastState();
      return;
    }

    // تسجيل السؤال لحظة تقديمه الفعلي فقط في سجلات جميع اللاعبين الحاضرين
    final curQ = _triviaQuestions[_currentTriviaIndex];
    final pHash = ArabicTextNormalizer.triviaQuestionHash(curQ.promptAr);
    final aHash = ArabicTextNormalizer.triviaAnswerHash(curQ.categorySlug, curQ.options[curQ.correctIndex]);
    recordSeenTriviaAcrossRoom([pHash], [aHash]);

    _currentPhase = 'trivia_question';
    _timerSeconds = _triviaTimePerQuestion;
    _answers.clear();
    _answerTimes.clear();

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        _timerSeconds--;
        _broadcastState();
      } else {
        timer.cancel();
        _evaluateTriviaRound();
      }
    });

    _broadcastState();
  }

  void _evaluateTriviaRound() {
    final currentQ = _triviaQuestions[_currentTriviaIndex];
    final scoring = (_gameSettings['scoring'] as Map<String, dynamic>?) ?? {};
    final totalSeconds = (_gameSettings['time_per_question'] as int?) ?? 15;

    for (int i = 0; i < _players.length; i++) {
      final p = _players[i];
      final answer = _answers[p.id];
      final isCorrect = currentQ.isOptionCorrect(answer ?? -1);
      final remaining = _answerTimes[p.id] ?? _timerSeconds;
      final roundScore = TriviaScorer.calculateFromSettings(
        isCorrect: isCorrect,
        remainingSeconds: remaining,
        totalSeconds: totalSeconds,
        questionPoints: currentQ.points,
        scoringSettings: scoring,
      );
      _players[i] = p.copyWith(score: p.score + roundScore);
    }

    _currentPhase = 'trivia_reveal';
    _broadcastState();

    _gameTimer?.cancel();
    _gameTimer = Timer(const Duration(seconds: 2), () {
      _currentPhase = 'trivia_leaderboard';
      _broadcastState();

      _gameTimer = Timer(const Duration(seconds: 3), () {
        nextTriviaQuestion();
      });
    });
  }

  void updatePlayerScore(String playerId, int points) {
    for (int i = 0; i < _players.length; i++) {
      if (_players[i].id == playerId) {
        _players[i] = _players[i].copyWith(score: _players[i].score + points);
        break;
      }
    }
    _broadcastState();
  }

  void nextTriviaQuestion() {
    _currentTriviaIndex++;
    _showNextTriviaQuestion();
  }

  void _broadcastMessage(GameMessage message) {
    final serialized = message.serialize();
    for (final ws in _clients.values) {
      try {
        ws.add(serialized);
      } catch (_) {}
    }
  }

  void _broadcastState() {
    final isRevealPhase = _currentPhase == 'trivia_reveal' || _currentPhase == 'trivia_leaderboard';

    final hostStateMap = {
      'room_code': roomCode,
      'game_mode': _gameMode,
      'current_phase': _currentPhase,
      'timer_seconds': _timerSeconds,
      'players': _players.map((p) => p.toJson()).toList(),
      'secret_word': _secretWord,
      'secret_category': _secretCategory,
      'spy_choices': _spyChoices,
      'settings': _gameSettings,
      'current_round': _currentRound,
      'total_rounds': _totalRounds,
      'time_per_question': _triviaTimePerQuestion,
      if (_currentPhase == 'trivia_question' && _triviaQuestions.isNotEmpty)
        'current_question': _triviaQuestions[_currentTriviaIndex].toJson(reveal: false)
      else if (isRevealPhase && _triviaQuestions.isNotEmpty)
        'current_question': _triviaQuestions[_currentTriviaIndex].toJson(reveal: true),
      'question_number': _currentTriviaIndex + 1,
      'total_questions': _triviaQuestions.length,
    };

    onStateChanged(hostStateMap);

    final isSpyGameBeforeResult = _gameMode == 'spy' &&
        (_currentPhase == 'role_hidden' ||
            _currentPhase == 'discussion' ||
            _currentPhase == 'voting' ||
            _currentPhase == 'last_chance');

    for (final entry in _clients.entries) {
      final clientId = entry.key;
      final ws = entry.value;

      final isClientSpy = _spyPlayerIds.contains(clientId);

      // حجب أدوار باقي اللاعبين والكلمة السرية للجاسوس منعاً لتسريب الدور السري
      final clientPlayers = _players.map((p) {
        if (!isSpyGameBeforeResult) return p.toJson();
        if (p.id == clientId) return p.toJson();
        return p.copyWith(role: null, currentWord: null).toJson();
      }).toList();

      final clientStateMap = {
        'room_code': roomCode,
        'game_mode': _gameMode,
        'current_phase': _currentPhase,
        'timer_seconds': _timerSeconds,
        'players': clientPlayers,
        'secret_word': (isSpyGameBeforeResult && isClientSpy) ? '' : _secretWord,
        'secret_category': _secretCategory,
        'spy_choices': _spyChoices,
        'settings': _gameSettings,
        'current_round': _currentRound,
        'total_rounds': _totalRounds,
        'time_per_question': _triviaTimePerQuestion,
        if (_currentPhase == 'trivia_question' && _triviaQuestions.isNotEmpty)
          'current_question': _triviaQuestions[_currentTriviaIndex].toJson(reveal: false)
        else if (isRevealPhase && _triviaQuestions.isNotEmpty)
          'current_question': _triviaQuestions[_currentTriviaIndex].toJson(reveal: true),
        'question_number': _currentTriviaIndex + 1,
        'total_questions': _triviaQuestions.length,
      };

      try {
        ws.add(GameMessage(type: 'state_update', payload: clientStateMap).serialize());
      } catch (_) {}
    }
  }
}
