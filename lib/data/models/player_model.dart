// Lamma - by Mohamed Ibrahim

class PlayerModel {
  final String id;
  final String name;
  final String emoji;
  final bool isHost;
  final int score;
  final int strikes;
  final bool isReady;
  final bool isKicked;
  final String? role; // 'citizen', 'spy', etc.
  final String? currentWord;

  String get avatar => emoji;

  const PlayerModel({
    required this.id,
    required this.name,
    String? emoji,
    String? avatar,
    this.isHost = false,
    this.score = 0,
    this.strikes = 0,
    this.isReady = false,
    this.isKicked = false,
    this.role,
    this.currentWord,
  }) : emoji = emoji ?? avatar ?? '🦁';

  PlayerModel copyWith({
    String? id,
    String? name,
    String? emoji,
    String? avatar,
    bool? isHost,
    int? score,
    int? strikes,
    bool? isReady,
    bool? isKicked,
    String? role,
    String? currentWord,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? avatar ?? this.emoji,
      isHost: isHost ?? this.isHost,
      score: score ?? this.score,
      strikes: strikes ?? this.strikes,
      isReady: isReady ?? this.isReady,
      isKicked: isKicked ?? this.isKicked,
      role: role ?? this.role,
      currentWord: currentWord ?? this.currentWord,
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? json['avatar'] as String? ?? '🦁',
    isHost: json['is_host'] as bool? ?? false,
    score: json['score'] as int? ?? 0,
    strikes: json['strikes'] as int? ?? 0,
    isReady: json['is_ready'] as bool? ?? false,
    isKicked: json['is_kicked'] as bool? ?? false,
    role: json['role'] as String?,
    currentWord: json['current_word'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'avatar': emoji,
    'is_host': isHost,
    'score': score,
    'strikes': strikes,
    'is_ready': isReady,
    'is_kicked': isKicked,
    'role': role,
    'current_word': currentWord,
  };
}
