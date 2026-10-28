// Lamma - by Mohamed Ibrahim

/// Pure domain logic for calculating Trivia scores based on correctness,
/// time taken, and game scoring settings.
class TriviaScorer {
  const TriviaScorer._();

  /// Calculates points for a trivia question response.
  ///
  /// Formula:
  /// - If correct: `100 + round(speed_bonus_max * remainingSeconds / totalSeconds)`
  /// - If wrong or no answer: `0`
  static int calculateScore({
    required bool isCorrect,
    required int remainingSeconds,
    required int totalSeconds,
    int basePoints = 100,
    int speedBonusMax = 100,
  }) {
    if (!isCorrect || totalSeconds <= 0) {
      return 0;
    }

    final clampedRemaining = remainingSeconds.clamp(0, totalSeconds);
    final speedBonus = ((speedBonusMax * clampedRemaining) / totalSeconds).round();
    return basePoints + speedBonus;
  }

  /// Calculates score using the map from `settings['scoring']`.
  ///
  /// Expected keys in [scoringSettings]:
  /// - `trivia_correct`: Base points for correct answer (default: 100)
  /// - `trivia_speed_bonus_max`: Max bonus for fastest answer (default: 100)
  /// - `trivia_wrong`: Points for wrong answer (default: 0)
  static int calculateFromSettings({
    required bool isCorrect,
    required int remainingSeconds,
    required int totalSeconds,
    Map<String, dynamic>? scoringSettings,
  }) {
    if (!isCorrect) {
      final wrongPoints = scoringSettings?['trivia_wrong'] as int? ?? 0;
      return wrongPoints;
    }

    final base = scoringSettings?['trivia_correct'] as int? ?? 100;
    final speedBonusMax = scoringSettings?['trivia_speed_bonus_max'] as int? ?? 100;

    return calculateScore(
      isCorrect: isCorrect,
      remainingSeconds: remainingSeconds,
      totalSeconds: totalSeconds,
      basePoints: base,
      speedBonusMax: speedBonusMax,
    );
  }
}
