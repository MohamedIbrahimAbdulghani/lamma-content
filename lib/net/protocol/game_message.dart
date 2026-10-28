// Lamma - by Mohamed Ibrahim

import 'dart:convert';

class GameMessage {
  final String type;
  final String? senderId;
  final Map<String, dynamic> payload;

  const GameMessage({
    required this.type,
    this.senderId,
    this.payload = const {},
  });

  factory GameMessage.fromJson(Map<String, dynamic> json) {
    return GameMessage(
      type: json['type'] as String? ?? 'unknown',
      senderId: json['sender_id'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (senderId != null) 'sender_id': senderId,
    'payload': payload,
  };

  String serialize() => jsonEncode(toJson());

  static GameMessage? deserialize(dynamic data) {
    try {
      if (data is String) {
        return GameMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
