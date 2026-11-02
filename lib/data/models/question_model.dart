// Lamma - by Mohamed Ibrahim

import '../../core/utils/arabic_text_normalizer.dart';

class QuestionModel {
  final int id;
  final int categoryId;
  final String categorySlug;
  final String type; // mcq, emoji_movie, true_false, complete_phrase, who_said
  final String promptAr;
  final String? emojiPrompt;
  final List<String> options;
  final int correctIndex; // -1 if hidden from client
  final String? saltedHash;
  final String difficulty;
  final String? explanationAr;
  final String source;
  final int points;

  const QuestionModel({
    required this.id,
    required this.categoryId,
    required this.categorySlug,
    required this.type,
    required this.promptAr,
    this.emojiPrompt,
    required this.options,
    this.correctIndex = -1,
    this.saltedHash,
    required this.difficulty,
    this.explanationAr,
    required this.source,
    this.points = 100,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      categorySlug: json['category_slug'] as String? ?? '',
      type: json['type'] as String? ?? 'mcq',
      promptAr: json['prompt_ar'] as String? ?? '',
      emojiPrompt: json['emoji_prompt'] as String?,
      options: (json['options'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      correctIndex: json['correct_index'] as int? ?? -1,
      saltedHash: json['salted_hash'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      explanationAr: json['explanation_ar'] as String?,
      source: json['source'] as String? ?? 'seed',
      points: json['points'] as int? ?? 100,
    );
  }

  /// التحقق من صحة الإجابة سواء كان correctIndex معلوماً أو عبر التجزئة المملحة (أوفلاين)
  bool isOptionCorrect(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= options.length) return false;
    if (correctIndex >= 0) {
      return optionIndex == correctIndex;
    }
    if (saltedHash != null && saltedHash!.isNotEmpty) {
      final computed = ArabicTextNormalizer.saltedAnswerHash(id, options[optionIndex]);
      return computed == saltedHash;
    }
    return false;
  }

  QuestionModel copyWith({
    int? id,
    int? categoryId,
    String? categorySlug,
    String? type,
    String? promptAr,
    String? emojiPrompt,
    List<String>? options,
    int? correctIndex,
    String? saltedHash,
    String? difficulty,
    String? explanationAr,
    String? source,
    int? points,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      type: type ?? this.type,
      promptAr: promptAr ?? this.promptAr,
      emojiPrompt: emojiPrompt ?? this.emojiPrompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      saltedHash: saltedHash ?? this.saltedHash,
      difficulty: difficulty ?? this.difficulty,
      explanationAr: explanationAr ?? this.explanationAr,
      source: source ?? this.source,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson({bool reveal = true}) => {
    'id': id,
    'category_id': categoryId,
    'category_slug': categorySlug,
    'type': type,
    'prompt_ar': promptAr,
    'emoji_prompt': emojiPrompt,
    'options': options,
    'correct_index': reveal ? correctIndex : -1,
    if (saltedHash != null) 'salted_hash': saltedHash,
    'difficulty': difficulty,
    'explanation_ar': reveal ? explanationAr : null,
    'source': source,
    'points': points,
  };
}
