// Lamma - by Mohamed Ibrahim

import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/features/trivia/domain/trivia_scorer.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_state.dart';

void main() {
  const sampleQuestions = [
    QuestionModel(
      id: 1,
      categoryId: 3,
      categorySlug: 'afeehat',
      type: 'mcq',
      promptAr: 'سؤال 1',
      options: ['أ', 'ب', 'ج', 'د'],
      correctIndex: 1, // 'ب'
      difficulty: 'medium',
      source: 'test',
    ),
    QuestionModel(
      id: 2,
      categoryId: 1,
      categorySlug: 'movies',
      type: 'mcq',
      promptAr: 'سؤال 2',
      options: ['س', 'ص', 'ع', 'ط'],
      correctIndex: 0, // 'س'
      difficulty: 'easy',
      source: 'test',
    ),
  ];

  group('TriviaScorer Unit Tests', () {
    test('Correct answer with maximum speed bonus gives 200 points', () {
      final score = TriviaScorer.calculateScore(
        isCorrect: true,
        remainingSeconds: 15,
        totalSeconds: 15,
        basePoints: 100,
        speedBonusMax: 100,
      );
      // 100 + round(100 * 15 / 15) = 200
      expect(score, equals(200));
    });

    test('Correct answer with partial remaining seconds calculates rounded speed bonus', () {
      final score = TriviaScorer.calculateScore(
        isCorrect: true,
        remainingSeconds: 7,
        totalSeconds: 15,
        basePoints: 100,
        speedBonusMax: 100,
      );
      // 100 + round(100 * 7 / 15) = 100 + round(46.666) = 147
      expect(score, equals(147));
    });

    test('Correct answer at 0 remaining seconds gives base 100 points without bonus', () {
      final score = TriviaScorer.calculateScore(
        isCorrect: true,
        remainingSeconds: 0,
        totalSeconds: 15,
        basePoints: 100,
        speedBonusMax: 100,
      );
      // 100 + round(100 * 0 / 15) = 100
      expect(score, equals(100));
    });

    test('Wrong answer gives 0 points', () {
      final score = TriviaScorer.calculateScore(
        isCorrect: false,
        remainingSeconds: 14,
        totalSeconds: 15,
      );
      expect(score, equals(0));
    });

    test('No answer or zero total seconds gives 0 points', () {
      expect(
        TriviaScorer.calculateScore(
          isCorrect: false,
          remainingSeconds: 0,
          totalSeconds: 15,
        ),
        equals(0),
      );

      expect(
        TriviaScorer.calculateScore(
          isCorrect: true,
          remainingSeconds: 5,
          totalSeconds: 0,
        ),
        equals(0),
      );
    });

    test('Scoring settings map is read correctly with custom values', () {
      final customSettings = {
        'trivia_correct': 150,
        'trivia_speed_bonus_max': 50,
        'trivia_wrong': 0,
      };

      final correctScore = TriviaScorer.calculateFromSettings(
        isCorrect: true,
        remainingSeconds: 10,
        totalSeconds: 20,
        scoringSettings: customSettings,
      );
      // 150 + round(50 * 10 / 20) = 150 + 25 = 175
      expect(correctScore, equals(175));

      final wrongScore = TriviaScorer.calculateFromSettings(
        isCorrect: false,
        remainingSeconds: 10,
        totalSeconds: 20,
        scoringSettings: customSettings,
      );
      expect(wrongScore, equals(0));
    });

    test('Clamping handles negative remaining seconds and exceeding total seconds', () {
      final underflow = TriviaScorer.calculateScore(
        isCorrect: true,
        remainingSeconds: -5,
        totalSeconds: 15,
      );
      expect(underflow, equals(100)); // clamped to 0 bonus

      final overflow = TriviaScorer.calculateScore(
        isCorrect: true,
        remainingSeconds: 30,
        totalSeconds: 15,
      );
      expect(overflow, equals(200)); // clamped to 15 (max bonus)
    });
  });

  group('Trivia Flow - Wrong Answer Advancing & Answer Locking', () {
    test('Answers lock after first tap and cannot be changed', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions,
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      expect(notifier.state.isAnswerLocked, isFalse);
      expect(notifier.state.selectedOptionIndex, isNull);

      // First tap: pick wrong answer (index 0)
      notifier.submitAnswer(0);

      expect(notifier.state.isAnswerLocked, isTrue);
      expect(notifier.state.selectedOptionIndex, equals(0));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));
      expect(notifier.state.lastEarnedPoints, equals(0));

      // Attempt second tap with correct answer (index 1)
      notifier.submitAnswer(1);

      // Must remain locked on the first selection
      expect(notifier.state.selectedOptionIndex, equals(0));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));
      expect(notifier.state.lastEarnedPoints, equals(0));
    });

    test('Wrong answer advances to leaderboard after 2 seconds (never stuck)', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions,
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Select wrong answer
      notifier.submitAnswer(0);
      expect(notifier.state.phase, equals(TriviaPhase.reveal));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));

      // Advance from reveal (after 2s delay)
      notifier.advanceFromReveal();

      expect(notifier.state.phase, equals(TriviaPhase.leaderboard));
    });

    test('Timeout enters wrong answer state and auto-advances to leaderboard (never stuck)', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions,
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Trigger timeout when time expires
      notifier.onTimeOut();

      expect(notifier.state.isAnswerLocked, isTrue);
      expect(notifier.state.selectedOptionIndex, isNull);
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));
      expect(notifier.state.lastEarnedPoints, equals(0));
      expect(notifier.state.phase, equals(TriviaPhase.reveal));

      // Auto-advance after 2 seconds
      notifier.advanceFromReveal();

      expect(notifier.state.phase, equals(TriviaPhase.leaderboard));
    });
  });

  group('Trivia Flow - Leaderboard Order & Score Updating', () {
    test('Points are added to player.score immediately and leaderboard is sorted descending', () {
      final initialPlayers = [
        const PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 100),
        const PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 250),
        const PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 180),
      ];

      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions,
        initialPlayers: initialPlayers,
        myPlayerId: '1',
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Initially, سارة (250) is 1st, كريم (180) is 2nd, أحمد (100) is 3rd
      var sorted = notifier.state.sortedPlayers;
      expect(sorted[0].name, equals('سارة'));
      expect(sorted[0].score, equals(250));
      expect(sorted[1].name, equals('كريم'));
      expect(sorted[1].score, equals(180));
      expect(sorted[2].name, equals('أحمد'));
      expect(sorted[2].score, equals(100));

      // أحمد answers correctly with full speed bonus (+200 points)
      notifier.submitAnswer(1);

      // Score should be 100 + 200 = 300 immediately
      final me = notifier.state.players.firstWhere((p) => p.id == '1');
      expect(me.score, equals(300));
      expect(notifier.state.lastEarnedPoints, equals(200));

      // Leaderboard order must now place أحمد (300) in 1st place!
      sorted = notifier.state.sortedPlayers;
      expect(sorted[0].name, equals('أحمد'));
      expect(sorted[0].score, equals(300));
      expect(sorted[1].name, equals('سارة'));
      expect(sorted[1].score, equals(250));
      expect(sorted[2].name, equals('كريم'));
      expect(sorted[2].score, equals(180));
    });

    test('Leaderboard advances to next question when questions remain', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions,
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      expect(notifier.state.currentQuestionIndex, equals(0));

      // Advance from reveal to leaderboard
      notifier.advanceFromReveal();
      expect(notifier.state.phase, equals(TriviaPhase.leaderboard));

      // Advance from leaderboard (after 3s)
      notifier.advanceFromLeaderboard();

      // Next question
      expect(notifier.state.phase, equals(TriviaPhase.question));
      expect(notifier.state.currentQuestionIndex, equals(1));
      expect(notifier.state.isAnswerLocked, isFalse);
      expect(notifier.state.selectedOptionIndex, isNull);
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.none));
    });

    test('Leaderboard advances to final results 36 after last question', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: sampleQuestions, // 2 questions
        totalSeconds: 15,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Question 1 -> Reveal -> Leaderboard
      notifier.advanceFromReveal();
      notifier.advanceFromLeaderboard();
      expect(notifier.state.currentQuestionIndex, equals(1));

      // Question 2 (last question) -> Reveal -> Leaderboard
      notifier.advanceFromReveal();
      expect(notifier.state.phase, equals(TriviaPhase.leaderboard));
      expect(notifier.state.isLastQuestion, isTrue);

      // Advance from leaderboard after last question
      notifier.advanceFromLeaderboard();

      // Completed phase (triggers navigation to /feedback/final-results)
      expect(notifier.state.phase, equals(TriviaPhase.completed));
    });
  });
}
