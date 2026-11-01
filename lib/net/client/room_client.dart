// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/utils/arabic_text_normalizer.dart';
import '../../data/storage/local_storage.dart';
import '../protocol/game_message.dart';

/// نتيجة محاولة الانضمام للغرفة
class JoinResult {
  final bool isSuccess;
  final String errorKey; // 'none', 'wrong_code', 'room_full', 'game_started', 'room_closed', 'timeout', 'network_error'
  final String errorMessage;

  const JoinResult.success()
      : isSuccess = true,
        errorKey = 'none',
        errorMessage = '';

  const JoinResult.failure({
    required this.errorKey,
    required this.errorMessage,
  }) : isSuccess = false;
}

class RoomClient {
  final String hostIp;
  final int port;
  final String roomCode;
  final String playerName;
  final String playerEmoji;
  final String deviceId;
  final LocalStorage? storage;

  final Function(Map<String, dynamic> state) onStateUpdated;
  final Function(String strikeMessage, int count, bool isKicked) onStrikeReceived;
  final VoidCallback onHostLeft;
  final Function(String errorMessage) onJoinError;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  RoomClient({
    required this.hostIp,
    this.port = 8080,
    required this.roomCode,
    required this.playerName,
    required this.playerEmoji,
    required this.deviceId,
    this.storage,
    required this.onStateUpdated,
    required this.onStrikeReceived,
    required this.onHostLeft,
    required this.onJoinError,
  });

  bool get isConnected => _isConnected;

  Future<JoinResult> connect({Duration timeout = const Duration(seconds: 4)}) async {
    final completer = Completer<JoinResult>();

    try {
      final wsUrl = 'ws://$hostIp:$port';
      _socket = await WebSocket.connect(wsUrl).timeout(timeout);
      _isConnected = true;

      // جمع بصمات ما شاهده اللاعب لإرسالها للمضيف عند الانضمام لمنع التكرار
      final seenTrivia = storage?.getSeenTriviaPromptHashes().take(2000).toList() ?? [];
      final seenTriviaAnswers = storage?.getSeenTriviaAnswerHashes().take(2000).toList() ?? [];
      final seenSpy = storage?.getSeenSpyHashes().take(2000).toList() ?? [];
      final seenCharades = storage?.getSeenCharadesHashes().take(2000).toList() ?? [];

      // إرسال رسالة طلب الانضمام مع البصمات
      _socket!.add(GameMessage(
        type: 'join',
        senderId: deviceId,
        payload: {
          'room_code': roomCode,
          'name': playerName,
          'emoji': playerEmoji,
          'device_id': deviceId,
          'seen_trivia': seenTrivia,
          'seen_trivia_answers': seenTriviaAnswers,
          'seen_spy': seenSpy,
          'seen_charades': seenCharades,
        },
      ).serialize());

      // بدء إرسال نبضات الحفاظ على الاتصال (Heartbeat)
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_isConnected && _socket != null) {
          try {
            _socket!.add(const GameMessage(type: 'heartbeat').serialize());
          } catch (_) {}
        }
      });

      _socket!.listen(
        (data) {
          final message = GameMessage.deserialize(data);
          if (message == null) return;

          switch (message.type) {
            case 'join_ack':
              if (!completer.isCompleted) {
                completer.complete(const JoinResult.success());
              }
              onStateUpdated(message.payload);
              _recordSeenContentFromState(message.payload);
              break;

            case 'state_update':
              onStateUpdated(message.payload);
              _recordSeenContentFromState(message.payload);
              break;

            case 'join_error':
              final errorKey = message.payload['error'] as String? ?? 'wrong_code';
              final errorMsg = message.payload['message'] as String? ?? 'تعذر الانضمام للغرفة';
              onJoinError(errorMsg);
              if (!completer.isCompleted) {
                completer.complete(JoinResult.failure(
                  errorKey: errorKey,
                  errorMessage: errorMsg,
                ));
              }
              disconnect();
              break;

            case 'strike_broadcast':
              final strikeMsg = message.payload['message'] as String? ?? '';
              final strikes = message.payload['strikes'] as int? ?? 1;
              final isKicked = message.payload['is_kicked'] as bool? ?? false;
              onStrikeReceived(strikeMsg, strikes, isKicked);
              break;

            case 'host_left':
              onHostLeft();
              disconnect();
              break;
          }
        },
        onDone: () {
          _isConnected = false;
          if (!completer.isCompleted) {
            completer.complete(const JoinResult.failure(
              errorKey: 'network_error',
              errorMessage: 'تم قطع الاتصال من قبل الخادم',
            ));
          }
        },
        onError: (e) {
          _isConnected = false;
          if (!completer.isCompleted) {
            completer.complete(JoinResult.failure(
              errorKey: 'network_error',
              errorMessage: 'حدث خطأ في الاتصال: $e',
            ));
          }
        },
      );

      return await completer.future.timeout(timeout, onTimeout: () {
        disconnect();
        return const JoinResult.failure(
          errorKey: 'timeout',
          errorMessage: 'انتهت مهلة انتظار استجابة المضيف',
        );
      });
    } on TimeoutException {
      _isConnected = false;
      return const JoinResult.failure(
        errorKey: 'timeout',
        errorMessage: 'انتهت مهلة الاتصال بالمضيف، تأكد من اتصالكما بنفس الشبكة',
      );
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      return JoinResult.failure(
        errorKey: 'network_error',
        errorMessage: 'تعذر الاتصال بالمضيف، تأكد من صحة العنوان والشبكة',
      );
    }
  }

  void _recordSeenContentFromState(Map<String, dynamic> payload) {
    if (storage == null) return;
    try {
      // 1. تحدي الشلة
      final rawQuestions = payload['trivia_questions'] as List<dynamic>?;
      if (rawQuestions != null && rawQuestions.isNotEmpty) {
        final promptHashes = <String>[];
        final answerHashes = <String>[];
        for (final item in rawQuestions) {
          if (item is Map<String, dynamic>) {
            final prompt = item['prompt_ar'] as String?;
            final cat = (item['category_slug'] ?? 'general') as String;
            final opts = (item['options'] as List<dynamic>?)?.map((e) => e.toString()).toList();
            final cIdx = item['correct_index'] as int? ?? 0;
            if (prompt != null && prompt.isNotEmpty) {
              promptHashes.add(ArabicTextNormalizer.triviaQuestionHash(prompt));
              if (opts != null && cIdx >= 0 && cIdx < opts.length) {
                answerHashes.add(ArabicTextNormalizer.triviaAnswerHash(cat, opts[cIdx]));
              }
            }
          }
        }
        if (promptHashes.isNotEmpty || answerHashes.isNotEmpty) {
          storage!.markTriviaHashesSeen(promptHashes: promptHashes, answerHashes: answerHashes);
        }
      }

      // 2. مين الجاسوس
      final secretWord = payload['secret_word'] as String?;
      if (secretWord != null && secretWord.trim().isNotEmpty) {
        final h = ArabicTextNormalizer.wordHash(secretWord);
        storage!.markSpyHashesSeen([h]);
      }

      // 3. مثّل ومتتكلمش
      final charadesWords = payload['charades_words'] as List<dynamic>?;
      if (charadesWords != null && charadesWords.isNotEmpty) {
        final hashes = charadesWords.map((e) => ArabicTextNormalizer.wordHash(e.toString())).toList();
        storage!.markCharadesHashesSeen(hashes);
      }
    } catch (_) {}
  }

  void sendIntent(String action, [Map<String, dynamic> extra = const {}]) {
    if (!_isConnected || _socket == null) return;
    final payload = Map<String, dynamic>.from(extra);
    payload['action'] = action;

    _socket!.add(GameMessage(
      type: 'intent',
      senderId: deviceId,
      payload: payload,
    ).serialize());
  }

  void sendViolation() {
    sendIntent('violation');
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _socket?.close();
    _socket = null;
  }
}
