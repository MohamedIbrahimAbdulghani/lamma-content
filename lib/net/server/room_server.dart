// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/player_model.dart';
import '../../data/models/question_model.dart';
import '../../features/trivia/domain/trivia_scorer.dart';
import '../protocol/game_message.dart';

class RoomServer {
  final String roomCode;
  final PlayerModel hostPlayer;
  final Function(Map<String, dynamic> state) onStateChanged;
  final Function(String message) onStrikeToast;

  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final List<PlayerModel> _players = [];

  String _gameMode = 'spy'; // 'spy', 'trivia', 'charades'
  String _currentPhase = 'lobby'; // 'lobby', 'role_hidden', 'discussion', 'voting', 'result', etc.
  int _timerSeconds = 0;
  Timer? _gameTimer;

  // Game Settings & State
  Map<String, dynamic> _gameSettings = {};
  List<QuestionModel> _triviaQuestions = [];
  int _currentTriviaIndex = 0;
  String _secretWord = '';
  String _secretCategory = '';
  List<String> _spyPlayerIds = [];
  final Map<String, int> _votes = {}; // voterId -> targetPlayerId
  final Map<String, int> _answers = {}; // playerId -> chosenIndex
  final Map<String, int> _answerTimes = {}; // playerId -> responseTimeMs

  RoomServer({
    required this.roomCode,
    required this.hostPlayer,
    required this.onStateChanged,
    required this.onStrikeToast,
  }) {
    _players.add(hostPlayer);
  }

  List<PlayerModel> get players => List.unmodifiable(_players);
  String get gameMode => _gameMode;
  String get currentPhase => _currentPhase;

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _server!.listen(_handleHttpRequest);
      await WakelockPlus.enable();
      _broadcastState();
    } catch (e) {
      debugPrint('Error starting RoomServer: $e');
    }
  }

  Future<void> stop() async {
    _gameTimer?.cancel();
    _broadcastMessage(const GameMessage(type: 'host_left'));
    for (final ws in _clients.values) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    await WakelockPlus.disable();
  }

  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((ws) {
        _handleClientConnection(ws);
      });
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
            final reqCode = message.payload['room_code'] as String? ?? '';
            final name = message.payload['name'] as String? ?? 'لاعب';
            final emoji = message.payload['emoji'] as String? ?? '🦁';
            final deviceId = message.payload['device_id'] as String? ?? '';

            if (reqCode != roomCode) {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'wrong_code', 'message': 'كود الغرفة غير صحيح'},
              ).serialize());
              ws.close();
              return;
            }

            if (_players.length >= 10) {
              ws.add(const GameMessage(
                type: 'join_error',
                payload: {'error': 'room_full', 'message': 'الغرفة مكتملة (الحد الأقصى 10 لاعبين)'},
              ).serialize());
              ws.close();
              return;
            }

            final validId = deviceId.isNotEmpty ? deviceId : const Uuid().v4();
            clientId = validId;
            _clients[validId] = ws;

            final newPlayer = PlayerModel(
              id: validId,
              name: name,
              emoji: emoji,
              isHost: false,
            );
            _players.removeWhere((p) => p.id == clientId);
            _players.add(newPlayer);

            ws.add(GameMessage(
              type: 'join_ack',
              payload: {
                'room_code': roomCode,
                'game_mode': _gameMode,
                'players': _players.map((p) => p.toJson()).toList(),
              },
            ).serialize());

            _broadcastState();
            break;

          case 'intent':
            final action = message.payload['action'] as String? ?? '';
            _handlePlayerIntent(message.senderId ?? clientId ?? '', action, message.payload);
            break;

          case 'heartbeat':
            // keep-alive ack
            break;
        }
      },
      onDone: () {
        if (clientId != null) {
          _clients.remove(clientId);
          _players.removeWhere((p) => p.id == clientId);
          _broadcastState();
        }
      },
      onError: (_) {
        if (clientId != null) {
          _clients.remove(clientId);
          _players.removeWhere((p) => p.id == clientId);
          _broadcastState();
        }
      },
    );
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
  }) {
    _secretWord = secretWord;
    _secretCategory = categoryName;
    _gameMode = 'spy';
    _currentPhase = 'role_hidden';
    _votes.clear();

    // Pick 1 or 2 spies
    final activePlayers = _players.where((p) => !p.isKicked).toList();
    if (activePlayers.isEmpty) return;

    final random = Random();
    final spyIndex = random.nextInt(activePlayers.length);
    _spyPlayerIds = [activePlayers[spyIndex].id];

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

  void startTriviaGame(List<QuestionModel> questions) {
    _triviaQuestions = questions;
    _currentTriviaIndex = 0;
    _gameMode = 'trivia';
    _answers.clear();
    _answerTimes.clear();
    _showNextTriviaQuestion();
  }

  void _showNextTriviaQuestion() {
    if (_currentTriviaIndex >= _triviaQuestions.length) {
      _currentPhase = 'final_results';
      _broadcastState();
      return;
    }

    _currentPhase = 'trivia_question';
    _timerSeconds = 15;
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
      final isCorrect = (answer == currentQ.correctIndex);
      final remaining = _answerTimes[p.id] ?? _timerSeconds;
      final roundScore = TriviaScorer.calculateFromSettings(
        isCorrect: isCorrect,
        remainingSeconds: remaining,
        totalSeconds: totalSeconds,
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
    final stateMap = {
      'room_code': roomCode,
      'game_mode': _gameMode,
      'current_phase': _currentPhase,
      'timer_seconds': _timerSeconds,
      'players': _players.map((p) => p.toJson()).toList(),
      'secret_word': _secretWord,
      'secret_category': _secretCategory,
      'settings': _gameSettings,
      if (_currentPhase == 'trivia_question' && _triviaQuestions.isNotEmpty)
        'current_question': _triviaQuestions[_currentTriviaIndex].toJson(),
      'question_number': _currentTriviaIndex + 1,
      'total_questions': _triviaQuestions.length,
    };

    onStateChanged(stateMap);
    _broadcastMessage(GameMessage(type: 'state_update', payload: stateMap));
  }
}
