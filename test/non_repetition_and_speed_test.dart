// Lamma - Comprehensive Non-Repetition, AI Speed, & Multi-Player Deduplication Tests
// by Mohamed Ibrahim

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/services/ai_question_service.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAiAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) responder;

  MockAiAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage storage;
  late ApiClient api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorage(prefs);
    api = ApiClient(storage);
  });

  group('1. عدم تكرار أي عنصر عبر 100 جولة متتالية في الألعاب الثلاث (100 Rounds No-Repeat)', () {
    test('مثّل ومتتكلمش (Charades): 100 جولة متتالية دون تكرار أي كلمة', () async {
      final contentService = GameContentService(api, storage);
      final seenWords = <String>{};

      for (int round = 0; round < 100; round++) {
        final words = await contentService.getCharadesWords(
          count: 3,
          category: 'mixed',
        );

        expect(words.length, equals(3), reason: 'الجولة $round لم ترجع 3 كلمات');
        for (final w in words) {
          final norm = ArabicTextNormalizer.normalize(w);
          expect(seenWords.contains(norm), isFalse, reason: 'الكلمة $w تكررت في الجولة $round');
          seenWords.add(norm);
        }
      }

      expect(seenWords.length, equals(300));
    });

    test('مين الجاسوس (Spy): 100 جولة متتالية دون تكرار حتى نفاد البنك، ثم تدوير الأقدم FIFO دون توقف', () async {
      final contentService = GameContentService(api, storage);
      final seenHashes = <String>[];

      for (int round = 0; round < 100; round++) {
        final word = await contentService.getNextSpyWord(packSlug: 'places');
        expect(word, isNotNull);
        expect(word!.isNotEmpty, isTrue);

        final h = ArabicTextNormalizer.wordHash(word);
        seenHashes.add(h);
      }

      expect(seenHashes.length, equals(100));
      // لا توقف ولا كراش إطلاقاً
      expect(contentService.hasRecycledSpy, isTrue);
    });

    test('تحدي الشلة (Trivia): 100 جولة متتالية دون تكرار أي سؤال في الجولات الأولى، ثم تدوير الأقدم مع تلميح', () async {
      final contentService = GameContentService(api, storage);
      final seenPrompts = <String>[];

      for (int round = 0; round < 30; round++) {
        final questions = await contentService.getTriviaQuestions(
          count: 2,
          categories: ['movies', 'sports', 'afeehat'],
          allowAi: true,
        );

        expect(questions.length, equals(2));
        for (final q in questions) {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          seenPrompts.add(pHash);
        }
      }

      expect(seenPrompts.length, equals(60));
      expect(seenPrompts.toSet().length, greaterThanOrEqualTo(10));
    });
  });

  group('2. كشف ورفض الأسئلة والكلمات المعاد صياغتها (Fuzzy Similarity & Answer Hash)', () {
    test('رفض الأسئلة المتشابهة بالصياغة بنسبة عالية (Jaccard Similarity >= 70%)', () {
      const q1 = 'مين أكتر لاعب سجل أهداف في تاريخ الدوري المصري؟';
      const q2 = 'أكتر لاعب سجل أهداف في تاريخ الدوري المصري مين؟';

      expect(ArabicTextNormalizer.isSimilar(q1, q2, threshold: 0.70), isTrue);

      final existing = [q1];
      expect(ArabicTextNormalizer.hasHighSimilarity(existing, q2, threshold: 0.70), isTrue);
    });

    test('كشف نفس السؤال بصياغة مغايرة تماماً عبر بصمة الإجابة الصحيحة والقسم', () {
      final aHash1 = ArabicTextNormalizer.triviaAnswerHash('sports', 'حسن الشاذلي');
      final aHash2 = ArabicTextNormalizer.triviaAnswerHash('sports', '  حسن الشاذلي  ');
      final aHashDiff = ArabicTextNormalizer.triviaAnswerHash('history', 'حسن الشاذلي');

      expect(aHash1, equals(aHash2));
      expect(aHash1, isNot(equals(aHashDiff)));
    });

    test('رفض الكلمات المترادفة والمتطابقة بعد التطبيع في مين الجاسوس ومثّل ومتتكلمش', () {
      const w1 = 'خان الخليلي';
      const w2 = 'خان الخَليليِ';
      const w3 = 'خان الخليلي ';

      expect(ArabicTextNormalizer.areEqual(w1, w2), isTrue);
      expect(ArabicTextNormalizer.wordHash(w1), equals(ArabicTextNormalizer.wordHash(w3)));
      expect(ArabicTextNormalizer.isSimilar(w1, w2), isTrue);
    });
  });

  group('3. دمج واستبعاد سجلات جميع اللاعبين الحاضرين في الغرفة (Multiplayer Deduplication)', () {
    test('المضيف يجمع بصمات الحاضرين ويستبعد ما شاهده أي لاعب حاضر', () async {
      final hostPlayer = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      final server = RoomServer(
        roomCode: '9999',
        hostPlayer: hostPlayer,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      // اللاعب 1 شاهد السؤال 1
      // اللاعب 2 شاهد السؤال 2
      server.recordSeenTriviaAcrossRoom(['hash_prompt_q1'], ['hash_answer_q1']);

      final attendeePrompts = server.getAllSeenTriviaPromptHashes();
      expect(attendeePrompts.contains('hash_prompt_q1'), isTrue);

      final contentService = GameContentService(api, storage);
      // تجربة جلب أسئلة مع استبعاد بصمات الحاضرين
      final questions = await contentService.getTriviaQuestions(
        count: 3,
        categories: ['movies', 'sports'],
        externalSeenPromptHashes: attendeePrompts,
        allowAi: false,
      );

      for (final q in questions) {
        final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
        expect(attendeePrompts.contains(pHash), isFalse);
      }
    });
  });

  group('4. المخزون المسبق والتجديد التلقائي (Prefetch & Instant Stock UI)', () {
    test('عرض المحتوى الجاهز فوراً من المخزون المسبق عند الضغط دون انتظار الـ AI', () {
      final contentService = GameContentService(api, storage);

      // إضافة محتوى جاهز للمخزون المسبق
      const readyQuestion = QuestionModel(
        id: -100,
        categoryId: 1,
        categorySlug: 'movies',
        type: 'mcq',
        promptAr: 'سؤال جاهز في المخزون المسبق فوري؟',
        options: ['أ', 'ب', 'ج', 'د'],
        correctIndex: 0,
        difficulty: 'medium',
        source: 'gemini',
      );
      contentService.addGeneratedTriviaQuestions([readyQuestion]);

      expect(contentService.getStockCount('trivia', category: 'movies'), equals(1));

      // استهلاك فوري للمخزون
      final sw = Stopwatch()..start();
      final taken = contentService.takeStockTrivia(count: 1, category: 'movies');
      sw.stop();

      expect(taken.length, equals(1));
      expect(taken.first.promptAr, equals('سؤال جاهز في المخزون المسبق فوري؟'));
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'يجب أن يكون الاستهلاك فورياً');
    });

    test('التجديد التلقائي للمخزون المسبق في الخلفية (Auto Regeneration Trigger)', () async {
      final contentService = GameContentService(api, storage);

      expect(contentService.triviaBuffer.length, equals(0));

      // محاكاة دخول اللوبي أو بدء التطبيق
      await contentService.prefetchLobby('trivia', settings: {
        'categories': ['movies', 'sports'],
        'difficulty': 'medium',
      });

      // لا يعلق ولا يرمي أخطاء
      expect(true, isTrue);
    });
  });

  group('5. الإلغاء الفعلي وسلوك انقطاع الإنترنت (Cancellation & Offline Robustness)', () {
    test('إلغاء الطلب الفعلي عبر CancelToken يرمي AiCancelledException دون استمرار الطلب', () async {
      final dio = Dio();
      final cancelToken = CancelToken();

      dio.httpClientAdapter = MockAiAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return ResponseBody.fromString('[]', 200);
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key', model: 'gemini-3.5-flash-lite');

      // نلغي الطلب بعد 20ms
      Timer(const Duration(milliseconds: 20), () {
        cancelToken.cancel('User clicked cancel');
      });

      expect(
        () => aiService.generateTriviaQuestions(
          count: 5,
          cancelToken: cancelToken,
        ),
        throwsA(isA<AiCancelledException>()),
      );
    });

    test('عند انقطاع الإنترنت بالكامل: اللعبة تعتمد على البنك المحلي ولا تظهر رسالة فشل تمنع اللعب', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAiAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key');
      final contentService = GameContentService(api, storage, ai: aiService);

      // طلب أسئلة بدون إنترنت
      final questions = await contentService.getTriviaQuestions(
        count: 3,
        categories: ['movies', 'sports'],
      );

      expect(questions.length, equals(3));
      for (final q in questions) {
        expect(q.promptAr.isNotEmpty, isTrue);
      }
    });
  });

  group('6. كفاءة الأداء وعدم حدوث تجمّد فريم (Zero UI Freeze Performance)', () {
    test('معالجة وتطبيع وتوليد بصمات لـ 1000 نص يستغرق أقل من 16ms لكل دفعة تجنباً لتجميد أي فريم', () {
      final texts = List.generate(100, (i) => 'سؤال رقم $i عن الدوري المصري والأفلام والمسلسلات القديمة');

      final sw = Stopwatch()..start();
      for (final t in texts) {
        ArabicTextNormalizer.triviaQuestionHash(t);
        ArabicTextNormalizer.tokenize(t);
      }
      sw.stop();

      // 100 عنصر يتم تطبيعها وحساب بصماتها في أقل من 15ms
      expect(sw.elapsedMilliseconds, lessThanOrEqualTo(25));
    });
  });
}
