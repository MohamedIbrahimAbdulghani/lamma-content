// Lamma - by Mohamed Ibrahim

class QuestionModel {
  final int id;
  final int categoryId;
  final String categorySlug;
  final String type; // mcq, emoji_movie, true_false, complete_phrase, who_said
  final String promptAr;
  final String? emojiPrompt;
  final List<String> options;
  final int correctIndex;
  final String difficulty;
  final String? explanationAr;
  final String source;

  const QuestionModel({
    required this.id,
    required this.categoryId,
    required this.categorySlug,
    required this.type,
    required this.promptAr,
    this.emojiPrompt,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    this.explanationAr,
    required this.source,
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
      correctIndex: json['correct_index'] as int? ?? 0,
      difficulty: json['difficulty'] as String? ?? 'medium',
      explanationAr: json['explanation_ar'] as String?,
      source: json['source'] as String? ?? 'seed',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_id': categoryId,
    'category_slug': categorySlug,
    'type': type,
    'prompt_ar': promptAr,
    'emoji_prompt': emojiPrompt,
    'options': options,
    'correct_index': correctIndex,
    'difficulty': difficulty,
    'explanation_ar': explanationAr,
    'source': source,
  };
}
