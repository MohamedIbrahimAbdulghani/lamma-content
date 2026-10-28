// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../protocol/game_message.dart';

class RoomClient {
  final String hostIp;
  final int port;
  final String roomCode;
  final String playerName;
  final String playerEmoji;
  final String deviceId;

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
    required this.onStateUpdated,
    required this.onStrikeReceived,
    required this.onHostLeft,
    required this.onJoinError,
  });

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    try {
      final wsUrl = 'ws://$hostIp:$port';
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));
      _isConnected = true;

      // Send join message
      _socket!.add(GameMessage(
        type: 'join',
        senderId: deviceId,
        payload: {
          'room_code': roomCode,
          'name': playerName,
          'emoji': playerEmoji,
          'device_id': deviceId,
        },
      ).serialize());

      // Start heartbeat
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
            case 'state_update':
              onStateUpdated(message.payload);
              break;

            case 'join_error':
              final errorMsg = message.payload['message'] as String? ?? 'تعذر الانضمام للغرفة';
              onJoinError(errorMsg);
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
        },
        onError: (_) {
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      return false;
    }
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
