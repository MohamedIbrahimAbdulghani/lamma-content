// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/core/routes/app_router.dart';
import 'package:lamma_party_game_app/core/routes/app_routes.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/ai_question_service.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/charades/controllers/charades_controller.dart';
import 'package:lamma_party_game_app/features/settings/settings_screen.dart';

class FailingAiService extends AiQuestionService {
  @override
  Future<List<String>> generateSpyWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 3,
  }) async {
    throw const AiNoInternetException();
  }

  @override
  Future<List<QuestionModel>> generateTriviaQuestions({
    required int count,
    String? category,
    List<String>? categories,
    String? difficulty,
    String? specificTopic,
    List<String> avoidTopics = const [],
    int maxRetries = 3,
  }) async {
    throw const AiNoInternetException();
  }

  @override
  Future<List<String>> generateCharadesWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 3,
  }) async {
    throw const AiNoInternetException();
  }
}

class HangingAiService extends AiQuestionService {
  @override
  Future<List<String>> generateSpyWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 3,
  }) async {
    await Future.delayed(const Duration(seconds: 10));
    return ['كلمة_متأخرة'];
  }

  @override
  Future<List<QuestionModel>> generateTriviaQuestions({
    required int count,
    String? category,
    List<String>? categories,
    String? difficulty,
    String? specificTopic,
    List<String> avoidTopics = const [],
    int maxRetries = 3,
  }) async {
    await Future.delayed(const Duration(seconds: 10));
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. بدء اللعبة بلاعب واحد في الألعاب الثلاث (1-Player Start)', () {
    test('بدء مين الجاسوس ينجح بلاعب واحد (المضيف فقط)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(roomProvider.notifier);
      roomNotifier.setSelectedGame(GameType.spy);
      roomNotifier.setPlayers([
        const PlayerModel(id: 'host_1', name: 'أحمد', isHost: true),
      ]);

      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: true,
      );

      final state = container.read(roomProvider);
      expect(state.currentPhase, equals('role_hidden'));
      expect(state.secretWord, isNotEmpty);
      expect(state.spyPlayerIds.length, equals(1));
      expect(state.players.first.id, equals('host_1'));
    });

    test('بدء تحدي الشلة ينجح بلاعب واحد ويوزع الأسئلة والوقت', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(roomProvider.notifier);
      roomNotifier.setSelectedGame(GameType.trivia);
      roomNotifier.setPlayers([
        const PlayerModel(id: 'host_1', name: 'أحمد', isHost: true),
      ]);

      final contentService = container.read(gameContentServiceProvider);
      final questions = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies'],
        difficulty: 'easy',
      );

      expect(questions.length, equals(5));

      roomNotifier.startTriviaGameRound(
        questions: questions,
        timePerQuestion: 15,
      );

      final state = container.read(roomProvider);
      expect(state.currentPhase, equals('trivia_question'));
      expect(state.triviaQuestions.length, equals(5));
      expect(state.timerSeconds, equals(15));
    });

    test('بدء مثّل ومتتكلمش ينجح بلاعب واحد ويهيئ الكلمات', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(roomProvider.notifier);
      roomNotifier.setSelectedGame(GameType.charades);
      roomNotifier.setPlayers([
        const PlayerModel(id: 'host_1', name: 'أحمد', isHost: true),
      ]);

      await container.read(charadesGameProvider.notifier).initGame();
      roomNotifier.startCharadesGameRound(roundSeconds: 60);

      final charadesState = container.read(charadesGameProvider);
      final roomState = container.read(roomProvider);

      expect(charadesState.words, isNotEmpty);
      expect(roomState.currentPhase, equals('charades_play'));
    });
  });

  group('2. البدء عند فشل الـ AI وانعدام الإنترنت (Offline Fallback)', () {
    test('مين الجاسوس تعود فوراً للمخزون المحلي عند فشل الـ AI', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final failingAi = FailingAiService();
      final contentService = GameContentService(
        ApiClient(storage),
        storage,
        ai: failingAi,
      );

      final word = await contentService.getNextSpyWord(packSlug: 'places');
      expect(word, isNotNull);
      expect(word, isNotEmpty);
    });

    test('تحدي الشلة تعود فوراً للأسئلة المحلية عند فشل الـ AI', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final failingAi = FailingAiService();
      final contentService = GameContentService(
        ApiClient(storage),
        storage,
        ai: failingAi,
      );

      final questions = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies'],
        difficulty: 'all',
      );
      expect(questions.length, equals(5));
      expect(questions.every((q) => q.promptAr.isNotEmpty), isTrue);
    });

    test('مثّل ومتتكلمش تعود فوراً للكلمات المحلية عند فشل الـ AI', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final failingAi = FailingAiService();
      final contentService = GameContentService(
        ApiClient(storage),
        storage,
        ai: failingAi,
      );

      final words = await contentService.getCharadesWords(count: 10, category: 'movies');
      expect(words.length, equals(10));
      expect(words.every((w) => w.isNotEmpty), isTrue);
    });
  });

  group('3. مهلة تحضير المحتوى وعدم تعليق اللعبة (Timeout & Guard Reset)', () {
    test('GameContentService يتجاوز تعليق الـ AI بعد المهلة المحددة ويعود للمحلي', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final hangingAi = HangingAiService();
      final contentService = GameContentService(
        ApiClient(storage),
        storage,
        ai: hangingAi,
      );

      final stopwatch = Stopwatch()..start();
      final word = await contentService.getNextSpyWord(packSlug: 'food');
      stopwatch.stop();

      expect(word, isNotNull);
      // يجب ألا ينتظر الـ 10 ثوانٍ بل يتجاوزها عبر المهلة
      expect(stopwatch.elapsed.inSeconds, lessThan(8));
    });

    test('resetStartingGuard تعيد isStartingRound إلى false دائماً', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(roomProvider.notifier);
      notifier.startGame();
      notifier.resetStartingGuard();

      expect(container.read(roomProvider).isStartingRound, isFalse);
    });
  });

  group('4. التحقق من مسارات التنقل (AppRoutes Defined in AppRouter)', () {
    test('جميع مسارات اللعب الرئيسية معرّفة بدقة في AppRouter', () {
      final routes = appRouter.configuration.routes.map((r) => (r as dynamic).path).toList();

      expect(routes.contains(AppRoutes.spyRole), isTrue);
      expect(routes.contains(AppRoutes.triviaPlay), isTrue);
      expect(routes.contains(AppRoutes.charadesHandoff), isTrue);
      expect(routes.contains(AppRoutes.charadesSpectator), isTrue);
      expect(routes.contains(AppRoutes.lobby), isTrue);
    });
  });

  group('5. شاشة الإعدادات وخلوها من الـ Overflow (SettingsScreen Overflow Fix)', () {
    testWidgets('شريط توليد الأسئلة بالذكاء الاصطناعي لا يسبب overflow على الشاشات الصغيرة',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600); // شاشة صغيرة جداً لاختبار الـ overflow
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('توليد الأسئلة بالذكاء الاصطناعي'), findsOneWidget);
      expect(find.text('Gemini AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
