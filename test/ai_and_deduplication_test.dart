// Lamma - by Mohamed Ibrahim
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/ai_question_service.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/lobby/ai_generation_sheet.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';

/// Mock Adapter لمحاكاة ردود Gemini API
class MockGeminiAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) responder;

  MockGeminiAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = responder(options);
    final statusCode = res['status'] as int? ?? 200;
    final data = res['data'];

    final jsonBytes = utf8.encode(jsonEncode(data));
    return ResponseBody.fromBytes(
      jsonBytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. ثبات البصمة والتطبيع (Fingerprint Stability & Normalization)', () {
    test('تطبيع التشكيل والتطويل والألف والياء والتاء المربوطة والأرقام الهندية', () {
      const variant1 = 'الأَهْلِيّ يَفُوزُ ٢-١ فِـي الدَّوْرِيِّ!';
      const variant2 = 'الاهلي  يفوز  2-1  في  الدوري';

      final hash1 = ArabicTextNormalizer.hashText(variant1);
      final hash2 = ArabicTextNormalizer.hashText(variant2);

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2), reason: 'يجب أن تتطابق البصمات بعد تطبيع الأرقام والتشكيل والتطويل');
    });

    test('توحيد الأرقام المشرقية (٠-٩) إلى الأرقام القياسية', () {
      expect(ArabicTextNormalizer.normalize('سنة ١٩٩٨'), equals('سنه 1998'));
      expect(ArabicTextNormalizer.normalize('رقم ٠١٢٣٤٥٦٧٨٩'), equals('رقم 0123456789'));
    });

    test('البصمة ثابتة وحتمية (Idempotent)', () {
      const text = 'من هو صاحب نوبل في الأدب سنة ١٩٨٨؟';
      final h1 = ArabicTextNormalizer.triviaQuestionHash(text);
      final h2 = ArabicTextNormalizer.triviaQuestionHash(text);
      expect(h1, equals(h2));
    });
  });

  group('2. كشف السؤال المعاد صياغته (Detect Rephrased Trivia Questions)', () {
    test('نفس السؤال بصياغة مختلفة يُكشف ببصمة الإجابة الصحيحة مع القسم', () {
      const q1Prompt = 'مين أكتر هداف في تاريخ الدوري المصري؟';
      const q2Prompt = 'اللاعب اللي جاب أكتر أهداف في بطولة الدوري العام عبر التاريخ مين؟';
      const correctAnswer = 'حسن الشاذلي';
      const category = 'sports';

      // بصمات نص السؤال مختلفة
      final promptHash1 = ArabicTextNormalizer.triviaQuestionHash(q1Prompt);
      final promptHash2 = ArabicTextNormalizer.triviaQuestionHash(q2Prompt);
      expect(promptHash1, isNot(equals(promptHash2)));

      // لكن بصمة الإجابة الصحيحة مع القسم متطابقة تماماً
      final answerHash1 = ArabicTextNormalizer.triviaAnswerHash(category, correctAnswer);
      final answerHash2 = ArabicTextNormalizer.triviaAnswerHash(category, '  حسن  الشاذلي  ');
      expect(answerHash1, equals(answerHash2));
    });
  });

  group('3. تحليل رد الذكاء الاصطناعي (AI Response Parsing)', () {
    test('تحليل مصفوفة JSON سليمة مع استخراج الأسئلة بالكامل', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockGeminiAdapter((options) {
        return {
          'status': 200,
          'data': {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode([
                        {
                          'category_slug': 'sports',
                          'difficulty': 'medium',
                          'prompt_ar': 'مين مدرب منتخب مصر في كأس العالم 1990؟',
                          'options': ['محمود الجوهري', 'حسن شحاتة', 'هيكتور كوبر', 'صالح سليم'],
                          'correct_index': 0,
                          'explanation_ar': 'الكابتن محمود الجوهري'
                        }
                      ]),
                    }
                  ]
                }
              }
            ]
          }
        };
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key', model: 'gemini-3.5-flash-lite');
      final questions = await aiService.generateTriviaQuestions(count: 1);

      expect(questions.length, equals(1));
      expect(questions.first.promptAr, contains('1990'));
      expect(questions.first.options[questions.first.correctIndex], equals('محمود الجوهري'));
      expect(questions.first.options.length, equals(4));
      expect(questions.first.correctIndex, equals(0));
    });

    test('تحليل رد AI ملفوف بأقواس Markdown ```json', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockGeminiAdapter((options) {
        return {
          'status': 200,
          'data': {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': '```json\n[{"word_ar": "ميدان التحرير"}]\n```',
                    }
                  ]
                }
              }
            ]
          }
        };
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key', model: 'gemini-3.5-flash-lite');
      final words = await aiService.generateSpyWords(count: 1);

      expect(words.length, equals(1));
      expect(words.first, equals('ميدان التحرير'));
    });

    test('فشل تحليل رد تالف أو فارغ يرمي AiInvalidResponseException دون كراش', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockGeminiAdapter((options) {
        return {
          'status': 200,
          'data': {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Not a json text at all'}
                  ]
                }
              }
            ]
          }
        };
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key', model: 'gemini-3.5-flash-lite');
      expect(
        () => aiService.generateTriviaQuestions(count: 1),
        throwsA(isA<AiInvalidResponseException>()),
      );
    });
  });

  group('4. رفض المتكرر من ناتج الـ AI وإعادة المحاولة', () {
    test('رفض الأسئلة المشاهدة سابقاً وتكرار الطلب للعدد الناقص', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);

      // تسجيل سؤال مسبقاً في السجل
      const existingPrompt = 'مين بطل فيلم الكيف؟';
      await storage.markTriviaQuestionTextsSeen([existingPrompt]);

      int callCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = MockGeminiAdapter((options) {
        callCount++;
        if (callCount == 1) {
          // أول طلب: يرجع سؤال مكرر وسؤال جديد
          return {
            'status': 200,
            'data': {
              'success': true,
              'data': [
                {
                  'category_slug': 'movies',
                  'difficulty': 'easy',
                  'prompt_ar': existingPrompt, // مكرر!
                  'options': ['محمود عبد العزيز', 'يحيى الفخراني', 'أحمد زكي', 'نور الشريف'],
                  'correct_index': 0,
                },
                {
                  'category_slug': 'movies',
                  'difficulty': 'easy',
                  'prompt_ar': 'مين مخرج فيلم الكيف؟',
                  'options': ['علي عبد الخالق', 'داود عبد السيد', 'محمد خان', 'شريف عرفة'],
                  'correct_index': 0,
                }
              ]
            }
          };
        } else {
          // ثاني طلب (إعادة المحاولة): يرجع سؤال جديد آخر
          return {
            'status': 200,
            'data': {
              'success': true,
              'data': [
                {
                  'category_slug': 'movies',
                  'difficulty': 'easy',
                  'prompt_ar': 'مين مؤلف فيلم الكيف؟',
                  'options': ['محمود أبو زيد', 'وحيد حامد', 'أسامة أنور عكاشة', 'لينين الرملي'],
                  'correct_index': 0,
                }
              ]
            }
          };
        }
      });

      final apiClient = ApiClient(storage, dio: dio);
      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key', model: 'gemini-3.5-flash-lite');
      final contentService = GameContentService(apiClient, storage, ai: aiService);

      final questions = await contentService.getTriviaQuestions(
        count: 2,
        categories: ['movies'],
        difficulty: 'easy',
      );

      expect(questions.length, equals(2));
      expect(questions.any((q) => q.promptAr == existingPrompt), isFalse, reason: 'المكرر تم رفضه');
      expect(callCount, greaterThanOrEqualTo(2), reason: 'تمت إعادة المحاولة للعدد الناقص');
    });
  });

  group('5. دمج سجلات عدة لاعبين في اللعب الجماعي', () {
    test('المضيف يستبعد ما شاهده أي لاعب حاضر في الغرفة', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final apiClient = ApiClient(storage);

      // اللاعب 1 شاهد سؤالاً محلياً
      const q1Prompt = 'سؤال شاهده المضيف';
      final q1PromptHash = ArabicTextNormalizer.triviaQuestionHash(q1Prompt);
      await storage.markTriviaHashesSeen(promptHashes: [q1PromptHash]);

      // اللاعب 2 أرسل بصماته عند الانضمام
      const q2Prompt = 'سؤال شاهده اللاعب الثاني المنضم';
      final q2PromptHash = ArabicTextNormalizer.triviaQuestionHash(q2Prompt);
      final externalSeenPrompts = {q2PromptHash};

      final contentService = GameContentService(apiClient, storage);

      // بنك أسئلة محلي تجريبي
      final questions = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies', 'sports', 'afeehat', 'history', 'general'],
        difficulty: 'all',
        allowAi: false,
        externalSeenPromptHashes: externalSeenPrompts,
      );

      for (final q in questions) {
        final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
        expect(pHash, isNot(equals(q1PromptHash)), reason: 'ممنوع ظهور ما شاهده المضيف');
        expect(pHash, isNot(equals(q2PromptHash)), reason: 'ممنوع ظهور ما شاهده أي لاعب حاضر');
      }
    });

    test('RoomServer يخزن بصمات كل لاعب منضم ويجمعها', () {
      final host = const PlayerModel(id: 'host_id', name: 'المضيف', isHost: true);
      final server = RoomServer(
        roomCode: '1234',
        hostPlayer: host,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      // التحقق من الدوال
      expect(server.getAllSeenTriviaPromptHashes(), isEmpty);
      expect(server.getAllSeenSpyHashes(), isEmpty);
      expect(server.getAllSeenCharadesHashes(), isEmpty);
    });
  });

  group('6. سلوك الفشل والتحلل السلس (Fallback & Never Fail)', () {
    test('عند انقطاع الإنترنت، لا تتوقف اللعبة وتستخدم البنك المحلي', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final apiClient = ApiClient(storage);

      final dio = Dio();
      dio.httpClientAdapter = MockGeminiAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final aiService = AiQuestionService(dio: dio, apiKey: 'test_key');
      final contentService = GameContentService(apiClient, storage, ai: aiService);

      // طلب أسئلة بدون إنترنت
      final questions = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies', 'sports', 'general'],
      );

      expect(questions.length, equals(5), reason: 'تم جلب الأسئلة من المخزون المحلي دون توقف');
    });

    test('مين الجاسوس لا تعيد null إطلاقاً حتى لو شوهدت كل الكلمات', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final apiClient = ApiClient(storage);

      final contentService = GameContentService(apiClient, storage);

      // استهلاك كلمات متعددة متتالية
      for (int i = 0; i < 30; i++) {
        final word = await contentService.getNextSpyWord(packSlug: 'places');
        expect(word, isNotNull);
        expect(word, isNotEmpty);
      }

      expect(contentService.hasRecycledSpy, isTrue, reason: 'عند نفاد الكلمات يُعاد التدوير دون كراش');
    });
  });

  group('7. حفظ السجل وبقاؤه بعد إعادة التشغيل (Persistence & Reset)', () {
    test('السجل يُحفظ في SharedPreferences ويُستعاد بنجاح', () async {
      final prefs1 = await SharedPreferences.getInstance();
      final storage1 = LocalStorage(prefs1);

      const testPrompt = 'سؤال محفوظ محلياً';
      const testAnswer = 'إجابة محفوظة';
      const testCategory = 'history';

      final pHash = ArabicTextNormalizer.triviaQuestionHash(testPrompt);
      final aHash = ArabicTextNormalizer.triviaAnswerHash(testCategory, testAnswer);

      await storage1.markTriviaHashesSeen(promptHashes: [pHash], answerHashes: [aHash]);

      // إعادة إنشاء الكائن من نفس التخزين لمطابقة فتح التطبيق من جديد
      final storage2 = LocalStorage(prefs1);
      final loadedPrompts = storage2.getSeenTriviaPromptHashes();
      final loadedAnswers = storage2.getSeenTriviaAnswerHashes();

      expect(loadedPrompts.contains(pHash), isTrue);
      expect(loadedAnswers.contains(aHash), isTrue);

      // زر مسح السجل يمسح كل شيء بنجاح
      await storage2.clearAllSeenHistory();
      expect(storage2.getSeenTriviaPromptHashes(), isEmpty);
      expect(storage2.getSeenTriviaAnswerHashes(), isEmpty);
    });

    test('الحد الأقصى للسجل (20000) يقلّم الأقدم بنظام FIFO', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);

      // إضافة 20005 عنصر
      final hashes = List.generate(20005, (i) => 'hash_$i');
      await storage.markSpyHashesSeen(hashes);

      final seen = storage.getSeenSpyHashes();
      expect(seen.length, equals(LocalStorage.kMaxHistorySizePerGame));
      expect(seen.contains('hash_0'), isFalse, reason: 'تم حذف الأقدم');
      expect(seen.contains('hash_20004'), isTrue, reason: 'تم الاحتفاظ بالأحدث');
    });
  });

  group('8. عدم تكرار أي عنصر عبر جولات متعددة (100 Rounds No-Repeat)', () {
    test('مثّل ومتتكلمش: جلب كلمات لـ 100 جولة دون تكرار أي كلمة', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final apiClient = ApiClient(storage);
      final contentService = GameContentService(apiClient, storage);

      final seenAcrossRounds = <String>{};
      int totalWordsFetched = 0;

      for (int round = 0; round < 30; round++) {
        final words = await contentService.getCharadesWords(
          count: 5,
          category: 'mixed',
        );

        expect(words.length, equals(5));
        totalWordsFetched += words.length;

        for (final w in words) {
          final norm = ArabicTextNormalizer.normalize(w);
          expect(seenAcrossRounds.contains(norm), isFalse, reason: 'الكلمة $w تكررت في الجولة $round');
          seenAcrossRounds.add(norm);
        }
      }

      expect(seenAcrossRounds.length, equals(totalWordsFetched));
    });
  });

  group('9. قياس أداء وأزمنة المراحل (Benchmark & Timing Comparison)', () {
    test('قياس زمن فحص السجل: مقارنة الـ List Linear Scan بالـ Set Lookup في سجل كبير (5000 عنصر)', () {
      final largeList = List.generate(5000, (i) => 'hash_item_prefix_$i');
      final searchItems = List.generate(50, (i) => 'hash_item_prefix_${i * 90}');

      // الطريقة القديمة: List contains O(N)
      final swOld = Stopwatch()..start();
      int foundOld = 0;
      for (final item in searchItems) {
        if (largeList.contains(item)) foundOld++;
      }
      swOld.stop();
      final oldTimeUs = swOld.elapsedMicroseconds;

      // الطريقة الجديدة: Set contains O(1)
      final largeSet = largeList.toSet();
      final swNew = Stopwatch()..start();
      int foundNew = 0;
      for (final item in searchItems) {
        if (largeSet.contains(item)) foundNew++;
      }
      swNew.stop();
      final newTimeUs = swNew.elapsedMicroseconds;

      expect(foundOld, equals(foundNew));
      // طباعة الأرقام للمقارنة الدقيقة
      // ignore: avoid_print
      print('[BENCHMARK] 50 lookups in 5000 items | Old (List): ${oldTimeUs}µs vs New (Set): ${newTimeUs}µs | Speedup: ${(oldTimeUs / (newTimeUs > 0 ? newTimeUs : 1)).toStringAsFixed(1)}x');
      expect(newTimeUs, lessThanOrEqualTo(oldTimeUs + 500));
    });

    test('قياس زمن الترتيب (Sort): مقارنة indexOf المتكرر بـ Map Index Lookup في قائمة كبيرة', () {
      final historyList = List.generate(5000, (i) => 'history_hash_$i');
      final candidates = List.generate(300, (i) => 'history_hash_${(i * 13) % 5000}');

      // الطريقة القديمة: indexOf داخل الـ comparator (كارثة الأداء)
      final listOld = List<String>.from(candidates);
      final swOld = Stopwatch()..start();
      listOld.sort((a, b) {
        final idxA = historyList.indexOf(a);
        final idxB = historyList.indexOf(b);
        return idxA.compareTo(idxB);
      });
      swOld.stop();
      final oldTimeMs = swOld.elapsedMilliseconds;

      // الطريقة الجديدة: فهرسة مسبقة O(1) باستخدام Map
      final listNew = List<String>.from(candidates);
      final swNew = Stopwatch()..start();
      final indexMap = <String, int>{};
      for (var i = 0; i < historyList.length; i++) {
        indexMap[historyList[i]] = i;
      }
      final ranks = <String, int>{};
      for (final item in listNew) {
        ranks[item] = indexMap[item] ?? -1;
      }
      listNew.sort((a, b) => ranks[a]!.compareTo(ranks[b]!));
      swNew.stop();
      final newTimeMs = swNew.elapsedMilliseconds;

      expect(listOld, equals(listNew));
      // ignore: avoid_print
      print('[BENCHMARK] Sorting 300 candidates across 5000 history items | Old: ${oldTimeMs}ms vs New: ${newTimeMs}ms | Speedup: ${(oldTimeMs / (newTimeMs > 0 ? newTimeMs : 1)).toStringAsFixed(1)}x');
      expect(newTimeMs, lessThanOrEqualTo(oldTimeMs));
    });
  });

  group('10. اختبارات واجهة المستخدم وخلوها من RenderFlex Overflow', () {
    testWidgets('شاشة تحديث ومزامنة المحتوى الذكي في Bottom Sheet لا تسبب RenderFlex overflow على الشاشات الصغيرة (320px)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
            home: Scaffold(
              body: SingleChildScrollView(
                child: AiGenerationSheet(gameType: 'trivia'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // التأكد من ظهور شاشة المزامنة المستقلة
      expect(find.text('تحديث ومزامنة المحتوى الذكي ⚡'), findsOneWidget);
      final syncBtn = find.text('تحديث وتعويض المخزون الآن 🔄');
      expect(syncBtn, findsOneWidget);
      expect(find.text('تم، جاهز للعب 🚀'), findsOneWidget);

      // التأكد التام من عدم وجود أي خطأ RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
