// Lamma - by Mohamed Ibrahim

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/charades/controllers/charades_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_state.dart';

void main() {
  group('ArabicTextNormalizer Tests (Problem 4)', () {
    test('Normalizes diacritics, alefs, taa marbuta, and spaces correctly', () {
      expect(
        ArabicTextNormalizer.normalize('خَانُ الخَلِيلِيّ'),
        equals('خان الخليلي'),
      );
      expect(
        ArabicTextNormalizer.normalize('الإرهابُ   والكَبَابْ'),
        equals('الارهاب والكباب'),
      );
      expect(
        ArabicTextNormalizer.normalize('الأهرامات!'),
        equals('الاهرامات'),
      );
      expect(
        ArabicTextNormalizer.normalize('مدرسة المشاغبين'),
        equals('مدرسه المشاغبين'),
      );
      expect(
        ArabicTextNormalizer.normalize('أبو علي'),
        equals('ابو علي'),
      );
    });

    test('areEqual returns true for variations with harakat or hamzas', () {
      expect(
        ArabicTextNormalizer.areEqual('خان الخليلي', 'خَانُ الخَلِيلي'),
        isTrue,
      );
      expect(
        ArabicTextNormalizer.areEqual('إبراهيم الأبيض', 'ابراهيم الابيض'),
        isTrue,
      );
      expect(
        ArabicTextNormalizer.contains(['خان الخليلي', 'برج القاهرة'], 'خَانُ الخَلِيلي'),
        isTrue,
      );
      expect(
        ArabicTextNormalizer.contains(['خان الخليلي', 'برج القاهرة'], 'شاطئ المعمورة'),
        isFalse,
      );
    });
  });

  group('Spy Game No-Repeat & New Round Tests (Problem 1 & 4)', () {
    late LocalStorage storage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorage(prefs);
    });

    test('startSpyGameRound picks unseen words and records them in history', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);

      // Round 1
      await roomNotifier.startSpyGameRound(packSlug: 'places', bootstrapData: null);
      final word1 = container.read(gameRoomProvider).secretWord;
      expect(word1, isNotEmpty);
      expect(storage.getSeenSpyWords().contains(word1), isTrue);

      // Round 2 - must get a different word
      await roomNotifier.startSpyGameRound(packSlug: 'places', bootstrapData: null);
      final word2 = container.read(gameRoomProvider).secretWord;
      expect(word2, isNotEmpty);
      expect(word2, isNot(equals(word1)));
      expect(storage.getSeenSpyWords().contains(word2), isTrue);
    });

    test('resetAllHistory clears seen history allowing reuse', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final contentService = container.read(gameContentServiceProvider);
      await storage.markSpyWordsSeen(['خان الخليلي', 'برج القاهرة']);
      expect(storage.getSeenSpyWords().length, equals(2));

      await contentService.resetAllHistory();
      expect(storage.getSeenSpyWords(), isEmpty);
      expect(storage.getSeenTriviaQuestionTexts(), isEmpty);
      expect(storage.getSeenCharadesWords(), isEmpty);
    });
  });

  group('Trivia Question Selection Tests (Problem 2)', () {
    const testQuestions = [
      QuestionModel(
        id: 101,
        categoryId: 1,
        categorySlug: 'movies',
        type: 'mcq',
        promptAr: 'سؤال الأفلام الأول',
        options: ['1', '2', '3', '4'],
        correctIndex: 0,
        difficulty: 'easy',
        source: 'test',
      ),
      QuestionModel(
        id: 102,
        categoryId: 2,
        categorySlug: 'sports',
        type: 'mcq',
        promptAr: 'سؤال الرياضة الثاني',
        options: ['أ', 'ب', 'ج', 'د'],
        correctIndex: 1,
        difficulty: 'medium',
        source: 'test',
      ),
      QuestionModel(
        id: 103,
        categoryId: 3,
        categorySlug: 'afeehat',
        type: 'mcq',
        promptAr: 'سؤال الأفيهات الثالث',
        options: ['س', 'ص', 'ع', 'ط'],
        correctIndex: 2,
        difficulty: 'hard',
        source: 'test',
      ),
    ];

    test('Can select specific question from available list', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: testQuestions,
        totalSeconds: 15,
        startWithSelection: true,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Initially in questionSelection phase
      expect(notifier.state.phase, equals(TriviaPhase.questionSelection));
      expect(notifier.state.remainingQuestionIndices.length, equals(3));

      // Player selects question at index 1 (Sports question)
      notifier.selectQuestion(1);

      expect(notifier.state.phase, equals(TriviaPhase.question));
      expect(notifier.state.currentQuestionIndex, equals(1));
      expect(notifier.state.currentQuestion?.promptAr, equals('سؤال الرياضة الثاني'));
      expect(notifier.state.playedQuestionIndices, contains(1));
      expect(notifier.state.remainingQuestionIndices, equals([0, 2]));
      expect(notifier.state.isAnswerLocked, isFalse);
    });

    test('Can select random question from remaining list', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: testQuestions,
        totalSeconds: 15,
        startWithSelection: true,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      notifier.selectRandomQuestion();

      expect(notifier.state.phase, equals(TriviaPhase.question));
      expect(notifier.state.playedQuestionIndices.length, equals(1));
      expect(notifier.state.remainingQuestionIndices.length, equals(2));
    });

    test('Leaderboard returns to questionSelection when more questions remain', () {
      final notifier = TriviaGameNotifier(
        initialQuestions: testQuestions,
        totalSeconds: 15,
        startWithSelection: true,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      // Select and play question 0
      notifier.selectQuestion(0);
      notifier.submitAnswer(0);

      // Reveal -> Leaderboard
      notifier.advanceFromReveal();
      expect(notifier.state.phase, equals(TriviaPhase.leaderboard));

      // Advance from leaderboard returns to questionSelection for the next question!
      notifier.advanceFromLeaderboard();
      expect(notifier.state.phase, equals(TriviaPhase.questionSelection));
      expect(notifier.state.remainingQuestionIndices, equals([1, 2]));
    });
  });

  group('Charades Teams, Instant Scoring & Zero-Repeat Tests (Problem 3)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Charades registers custom teams and updates score immediately on markCorrect', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(charadesGameProvider.notifier);

      final customTeams = [
        const PlayerModel(id: 't1', name: 'فريق النسور', emoji: '🦅', score: 0),
        const PlayerModel(id: 't2', name: 'فريق الذئاب', emoji: '🐺', score: 0),
      ];

      await notifier.initGame(
        initialPlayers: customTeams,
        roundSeconds: 60,
        roundsPerPlayer: 1,
      );

      final state = container.read(charadesGameProvider);
      expect(state.players.length, equals(2));
      expect(state.currentPlayer?.name, equals('فريق النسور'));
      expect(state.words.isNotEmpty, isTrue);

      notifier.startRound();
      final word1 = state.currentWord;

      // Click "عرفوها ✅" -> instantly adds 1 point to active team
      notifier.markCorrect();

      final stateAfterCorrect = container.read(charadesGameProvider);
      expect(stateAfterCorrect.currentPlayer?.score, equals(1));
      expect(stateAfterCorrect.players.firstWhere((p) => p.id == 't1').score, equals(1));
      expect(stateAfterCorrect.currentWord, isNot(equals(word1))); // Next word, never repeats

      // Click "تخطي ❌" -> moves to next word without points
      notifier.markPass();
      final stateAfterPass = container.read(charadesGameProvider);
      expect(stateAfterPass.currentPlayer?.score, equals(1)); // score unchanged
    });

    test('Charades completes game cleanly when words or rounds finish without endless loop', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(charadesGameProvider.notifier);

      final players = [
        const PlayerModel(id: '1', name: 'أحمد', emoji: '🦁', score: 0),
      ];

      await notifier.initGame(
        initialPlayers: players,
        roundsPerPlayer: 1,
      );

      notifier.startRound();
      final isDone = notifier.advanceToNextTurn();
      expect(isDone, isTrue);
      expect(container.read(charadesGameProvider).isGameCompleted, isTrue);
    });
  });
}
