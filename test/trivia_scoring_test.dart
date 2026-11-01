// Lamma - by Mohamed Ibrahim

import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/features/trivia/domain/trivia_scorer.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_state.dart';

void main() {
  const q1 = QuestionModel(
    id: 1,
    categoryId: 1,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'ما هي عاصمة مصر؟',
    options: ['الإسكندرية', 'القاهرة', 'الجيزة', 'أسوان'],
    correctIndex: 1, // القاهرة
    difficulty: 'medium',
    source: 'test',
    points: 150,
  );

  const q2 = QuestionModel(
    id: 2,
    categoryId: 1,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'كم عدد قارات العالم القديم؟',
    options: ['3', '5', '7', '4'],
    correctIndex: 0, // 3
    difficulty: 'medium',
    source: 'test',
    points: 200,
  );

  const q3 = QuestionModel(
    id: 3,
    categoryId: 1,
    categorySlug: 'general',
    type: 'mcq',
    promptAr: 'أطول نهر في العالم؟',
    options: ['الأمازون', 'النيل', 'المسيسيبي', 'الدانوب'],
    correctIndex: 1, // النيل
    difficulty: 'easy',
    source: 'test',
    points: 100,
  );

  final testPlayers = [
    const PlayerModel(id: 'player_1', name: 'أحمد', avatar: '🦁', score: 0),
    const PlayerModel(id: 'player_2', name: 'سارة', avatar: '🦊', score: 0),
  ];

  group('Trivia Scoring Unit Tests', () {
    test('TriviaScorer: Correct answer returns question points', () {
      final score1 = TriviaScorer.calculateScore(
        isCorrect: true,
        questionPoints: 150,
      );
      expect(score1, equals(150));

      final score2 = TriviaScorer.calculateScore(
        isCorrect: true,
        questionPoints: 250,
      );
      expect(score2, equals(250));
    });

    test('TriviaScorer: Wrong answer returns 0 points', () {
      final score = TriviaScorer.calculateScore(
        isCorrect: false,
        questionPoints: 150,
      );
      expect(score, equals(0));
    });

    test('(أ) إجابة صحيحة تضيف نقاط السؤال للاعب وتحدث lastEarnedPoints', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: [q1],
        totalSeconds: 15,
        initialPlayers: testPlayers,
        myPlayerId: 'player_1',
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      expect(notifier.state.players.first.score, equals(0));

      // اختيار الإجابة الصحيحة (مؤشر 1)
      notifier.submitAnswer(1);

      final me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(150));
      expect(notifier.state.lastEarnedPoints, equals(150));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.correct));
    });

    test('(ب) إجابة خاطئة تضيف 0 نقطة', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: [q1],
        totalSeconds: 15,
        initialPlayers: testPlayers,
        myPlayerId: 'player_1',
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      // اختيار إجابة خاطئة (مؤشر 0 بدلاً من 1)
      notifier.submitAnswer(0);

      final me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(0));
      expect(notifier.state.lastEarnedPoints, equals(0));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));
    });

    test('(ج) انتهاء الوقت دون إجابة يضيف 0 نقطة ويعتبر إجابة خاطئة', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: [q1],
        totalSeconds: 15,
        initialPlayers: testPlayers,
        myPlayerId: 'player_1',
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      // محاكاة انتهاء الوقت
      notifier.onTimeOut();

      final me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(0));
      expect(notifier.state.lastEarnedPoints, equals(0));
      expect(notifier.state.answerResult, equals(TriviaAnswerResult.wrong));
      expect(notifier.state.isAnswerLocked, isTrue);
    });

    test('(د) تراكم النقاط عبر أكثر من سؤال دون تصفير بين الأسئلة', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: [q1, q2, q3],
        totalSeconds: 15,
        initialPlayers: testPlayers,
        myPlayerId: 'player_1',
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      // السؤال 1 (150 نقطة): إجابة صحيحة
      notifier.submitAnswer(1);
      var me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(150));

      // الانتقال للسؤال 2 (من الكشف إلى الترتيب ثم السؤال التالي)
      notifier.advanceFromReveal();
      notifier.advanceFromLeaderboard();

      expect(notifier.state.currentQuestionIndex, equals(1));
      // التأكد أن النقاط لم تُصفّر
      me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(150));

      // السؤال 2 (200 نقطة): إجابة صحيحة
      notifier.submitAnswer(0);
      me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(350)); // 150 + 200

      // الانتقال للسؤال 3
      notifier.advanceFromReveal();
      notifier.advanceFromLeaderboard();

      expect(notifier.state.currentQuestionIndex, equals(2));
      // السؤال 3 (100 نقطة): إجابة خاطئة
      notifier.submitAnswer(0); // إجابة خاطئة
      me = notifier.state.players.firstWhere((p) => p.id == 'player_1');
      expect(me.score, equals(350)); // يظل 350
    });

    test('(هـ) منع تكرار النقط لنفس السؤال عند الضغط المتكرر (Double Tap Protection)', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: [q1],
        totalSeconds: 15,
        initialPlayers: testPlayers,
        myPlayerId: 'player_1',
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      // الضغطة الأولى: صحيحة
      notifier.submitAnswer(1);
      final scoreAfterFirstTap = notifier.state.players.firstWhere((p) => p.id == 'player_1').score;
      expect(scoreAfterFirstTap, equals(150));
      expect(notifier.state.isAnswerLocked, isTrue);

      // ضغطات متكررة سريعة على نفس الخيار أو خيارات أخرى
      notifier.submitAnswer(1);
      notifier.submitAnswer(2);
      notifier.submitAnswer(0);

      // السكور يظل كما هو دون أي زيادة أو تكرار
      final scoreAfterMultiTap = notifier.state.players.firstWhere((p) => p.id == 'player_1').score;
      expect(scoreAfterMultiTap, equals(150));
    });
  });
}
