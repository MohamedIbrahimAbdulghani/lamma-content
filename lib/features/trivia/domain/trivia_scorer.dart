// Lamma - by Mohamed Ibrahim

/// Pure domain logic for calculating Trivia scores based on correctness
/// and question points.
class TriviaScorer {
  const TriviaScorer._();

  /// Calculates points for a trivia question response.
  static int calculateScore({
    required bool isCorrect,
    int questionPoints = 100,
    int remainingSeconds = 0,
    int totalSeconds = 0,
    int basePoints = 100,
    int speedBonusMax = 100,
  }) {
    if (!isCorrect) {
      return 0;
    }
    if (totalSeconds == 0 && remainingSeconds > 0) {
      return 0;
    }
    if (totalSeconds > 0 && speedBonusMax > 0) {
      final clampedRemaining = remainingSeconds.clamp(0, totalSeconds);
      final bonus = ((speedBonusMax * clampedRemaining) / totalSeconds).round();
      final base = (questionPoints != 100 && basePoints == 100) ? questionPoints : basePoints;
      return base + bonus;
    }
    return questionPoints;
  }

  /// Calculates score using question points or fallback base
  static int calculateFromSettings({
    required bool isCorrect,
    int questionPoints = 100,
    int remainingSeconds = 0,
    int totalSeconds = 0,
    Map<String, dynamic>? scoringSettings,
  }) {
    if (!isCorrect) {
      return 0;
    }
    final base = (scoringSettings?['trivia_correct'] as int?) ?? questionPoints;
    final speedMax = (scoringSettings?['trivia_speed_bonus_max'] as int?) ?? 0;
    if (totalSeconds > 0 && speedMax > 0) {
      final clampedRemaining = remainingSeconds.clamp(0, totalSeconds);
      final bonus = ((speedMax * clampedRemaining) / totalSeconds).round();
      return base + bonus;
    }
    return base;
  }
}
