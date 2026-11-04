// Lamma - Auto-Replenish, Concurrency Lock, & Category Slug Tests
// by Mohamed Ibrahim

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/core/utils/category_localization.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
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

  group('1. Category Slug Unification & Arabic Localization', () {
    test('CategoryLocalization maps slugs to clean Arabic names', () {
      expect(CategoryLocalization.getTriviaCategoryName('movies'), equals('أفلام ومسلسلات'));
      expect(CategoryLocalization.getTriviaCategoryName('guess_movie'), equals('أفلام ومسلسلات'));
      expect(CategoryLocalization.getTriviaCategoryName('sports'), equals('كورة مصرية'));
      expect(CategoryLocalization.getTriviaCategoryName('kora'), equals('كورة مصرية'));
      expect(CategoryLocalization.getTriviaCategoryName('history'), equals('تاريخ وجغرافيا'));
      expect(CategoryLocalization.getTriviaCategoryName('afeehat'), equals('إفيهات وقفشات'));
      expect(CategoryLocalization.getTriviaCategoryName('general'), equals('معلومات عامة'));
    });

    test('Spy pack slug localization maps food/foods and movies to Arabic', () {
      expect(CategoryLocalization.getSpyPackName('movies'), equals('أفلام'));
      expect(CategoryLocalization.getSpyPackName('places'), equals('أماكن ومعالم'));
      expect(CategoryLocalization.getSpyPackName('food'), equals('أكلات شعبية'));
      expect(CategoryLocalization.getSpyPackName('foods'), equals('أكلات شعبية'));
    });

    test('Charades category slug localization maps to Arabic', () {
      expect(CategoryLocalization.getCharadesCategoryName('movies'), equals('أفلام'));
      expect(CategoryLocalization.getCharadesCategoryName('series'), equals('مسلسلات'));
      expect(CategoryLocalization.getCharadesCategoryName('actions'), equals('أفعال وحركات'));
      expect(CategoryLocalization.getCharadesCategoryName('jobs'), equals('مهن'));
    });

    test('Canonical slug normalization returns consistent english slugs', () {
      expect(CategoryLocalization.canonicalTriviaSlug('guess_movie'), equals('movies'));
      expect(CategoryLocalization.canonicalTriviaSlug('أفلام ومسلسلات'), equals('movies'));
      expect(CategoryLocalization.canonicalTriviaSlug('kora'), equals('sports'));
      expect(CategoryLocalization.canonicalTriviaSlug('كورة مصرية'), equals('sports'));
      expect(CategoryLocalization.canonicalSpyPackSlug('أكلات شعبية'), equals('foods'));
      expect(CategoryLocalization.canonicalCharadesCategorySlug('أفعال وحركات'), equals('actions'));
    });
  });

  group('2. Auto-Replenishment Threshold (available <= required + 2*required)', () {
    test('shouldReplenishTrivia returns true when available is below threshold', () {
      final contentService = GameContentService(api, storage);

      // Category movies: fallback has 5 items. If required = 5, safety margin = 10, threshold = 15.
      // Available (5) <= 15 -> shouldReplenish is true!
      final shouldReplenish = contentService.shouldReplenishTrivia(
        requiredCount: 5,
        categories: ['movies'],
        difficulty: 'all',
      );
      expect(shouldReplenish, isTrue);
    });

    test('shouldReplenishSpy returns true when available is below threshold', () {
      final contentService = GameContentService(api, storage);

      // Places pack has 20 items. If required = 10, safety margin = 20, threshold = 30.
      // Available (20) <= 30 -> shouldReplenish is true!
      final shouldReplenish = contentService.shouldReplenishSpy(
        requiredCount: 10,
        packSlug: 'places',
      );
      expect(shouldReplenish, isTrue);
    });
  });

  group('3. Concurrency Lock per (game, category, difficulty)', () {
    test('concurrent autoReplenish requests share single AI invocation', () async {
      int apiCallCount = 0;

      api.dio.httpClientAdapter = MockAiAdapter((options) async {
        if (options.path.contains('/content/generate')) {
          apiCallCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          final prompts = [
            'ما هو اسم فيلم أحمد زكي الذي جسد فيه شخصية رئيس الجمهورية؟',
            'من قام بدور عاطف السكري في مسرحية العيال كبرت الشهيرة؟',
            'إيه اسم القرية التي دارت فيها أحداث فيلم الزوجة الثانية؟',
            'من أخرج فيلم باب الحديد وشارك أيضاً في التمثيل فيه بدور قناوي؟',
            'أي عام تم إنتاج فيلم الكيف للكاتب محمود أبو زيد؟',
            'من صاحب الإفيه الشهير نشنت يا فالح في السينما المصرية؟',
            'من شارك الفنانة شادية بطولة فيلم مراتي مدير عام عام 1966؟',
            'ما هو الفيلم المصري الحاصل على الترتيب الأول في قائمة أفضل 100 فيلم؟',
            'من كتب سيناريو وحوار فيلم الهروب بطولة أحمد زكي؟',
            'ما هي الجائزة الدولية التي فاز بها فيلم المومياء للمخرج شادي عبد السلام؟',
            'من قام بتجسيد شخصية المعلم سردينة في مسلسل لن أعيش في جلباب أبي؟',
            'ما اسم الشخصية التي قدمها عادل إمام في فيلم طيور الظلام؟',
            'من هو بطل فيلم الرسالة في نسخته العربية من إخراج مصطفى العقاد؟',
            'ما اسم الفيلم الذي جمع بين عبد الحليم حافظ وفاتن حمامة لأول مرة؟',
            'من لحن أغاني مسرحية ريا وسكينة بطولة سهير البابلي وشادية؟',
            'من صاحب الموسيقى التصويرية الشهيرة لفيلم دعاء الكروان عام 1959؟',
            'من جسد دور عتريس في فيلم شيء من الخوف للمخرج حسين كمال؟',
            'ما اسم المسلسل الذي جمع يحيى الفخراني وصلاح السعدني من تأليف أسامة أنور عكاشة؟',
          ];
          final items = List.generate(prompts.length, (idx) => '''
          {
            "category_slug": "movies",
            "difficulty": "medium",
            "prompt_ar": "${prompts[idx]}",
            "options": ["خيار أ $idx", "خيار ب $idx", "خيار ج $idx", "خيار د $idx"],
            "correct_index": 0
          }
          ''').join(',');
          final jsonString = '{"status":"success","data":{"items":[$items]}}';
          return ResponseBody.fromString(jsonString, 200, headers: {
            'content-type': ['application/json']
          });
        }
        return ResponseBody.fromString('{}', 200);
      });

      final contentService = GameContentService(api, storage);

      // Launch 3 simultaneous replenishment calls for the exact same tuple
      await Future.wait([
        contentService.autoReplenishTriviaIfNeeded(
          requiredCount: 5,
          categories: ['movies'],
          difficulty: 'medium',
        ),
        contentService.autoReplenishTriviaIfNeeded(
          requiredCount: 5,
          categories: ['movies'],
          difficulty: 'medium',
        ),
        contentService.autoReplenishTriviaIfNeeded(
          requiredCount: 5,
          categories: ['movies'],
          difficulty: 'medium',
        ),
      ]);

      // Exactly 1 API call should have been made thanks to concurrency lock
      expect(apiCallCount, equals(1));
    });
  });

  group('4. Zero-stock Auto-generation & AI Deduplication', () {
    test('Category with zero unseen items triggers AI and delivers required count without dialog', () async {
      // Mark all fallback questions as seen to create true 0 stock
      for (final q in kFallbackTriviaQuestions) {
        if (q.categorySlug == 'movies') {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          await storage.markTriviaHashesSeen(promptHashes: [pHash]);
        }
      }

      int generatedCallCount = 0;
      api.dio.httpClientAdapter = MockAiAdapter((options) async {
        if (options.path.contains('/content/generate')) {
          generatedCallCount++;
          final jsonString = '''
          {
            "status": "success",
            "data": {
              "items": [
                {
                  "category_slug": "movies",
                  "difficulty": "medium",
                  "prompt_ar": "ما هو أول فيلم سينمائي مصري ناطق بالصوت عام 1932؟",
                  "options": ["أولاد الذوات", "الوردة البيضاء", "عنتر وعبلة", "سلامة في خير"],
                  "correct_index": 0
                },
                {
                  "category_slug": "movies",
                  "difficulty": "medium",
                  "prompt_ar": "من جسد شخصية حميدة في فيلم زقاق المدق عن رواية نجيب محفوظ؟",
                  "options": ["شادية", "سعاد حسني", "فاتن حمامة", "ماجدة"],
                  "correct_index": 0
                },
                {
                  "category_slug": "movies",
                  "difficulty": "medium",
                  "prompt_ar": "ما اسم السفينة في فيلم أمير البحار بطولة محمد هنيدي؟",
                  "options": ["القبطان عزوز", "أمير بحار 1", "المحروسة", "تيتانيك الشرق"],
                  "correct_index": 0
                }
              ]
            }
          }
          ''';
          return ResponseBody.fromString(jsonString, 200, headers: {
            'content-type': ['application/json']
          });
        }
        return ResponseBody.fromString('{}', 200);
      });

      final contentService = GameContentService(api, storage);

      // Request 3 questions in category movies
      final questions = await contentService.getTriviaQuestions(
        count: 3,
        categories: ['movies'],
        difficulty: 'medium',
      );

      expect(questions.length, equals(3));
      expect(generatedCallCount, greaterThan(0));
      for (final q in questions) {
        expect(q.categorySlug, equals('movies'));
      }
    });
  });

  group('5. AI Failure Reason & Localized Exception', () {
    test('Offline / Connection failure sets real Arabic error message and category name', () async {
      // Mark all fallback questions as seen
      for (final q in kFallbackTriviaQuestions) {
        if (q.categorySlug == 'movies') {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          await storage.markTriviaHashesSeen(promptHashes: [pHash]);
        }
      }

      // Simulate connection error
      api.dio.httpClientAdapter = MockAiAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'SocketException: OS Error: Connection refused',
        );
      });

      final contentService = GameContentService(api, storage);

      try {
        await contentService.getTriviaQuestions(
          count: 5,
          categories: ['movies'],
          difficulty: 'medium',
        );
        fail('Should throw InsufficientTriviaQuestionsException');
      } on InsufficientTriviaQuestionsException catch (e) {
        // Must contain Arabic category name, NOT raw 'movies'
        expect(e.toString(), contains('أفلام ومسلسلات'));
        expect(e.toString(), contains('لا يوجد اتصال بالإنترنت'));
      }
    });

    test('HTTP 429 Rate Limit sets specific Arabic message', () async {
      for (final q in kFallbackTriviaQuestions) {
        if (q.categorySlug == 'movies') {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          await storage.markTriviaHashesSeen(promptHashes: [pHash]);
        }
      }

      api.dio.httpClientAdapter = MockAiAdapter((options) async {
        return ResponseBody.fromString('{"error": "Too Many Requests"}', 429);
      });

      final contentService = GameContentService(api, storage);

      try {
        await contentService.getTriviaQuestions(
          count: 5,
          categories: ['movies'],
          difficulty: 'medium',
        );
        fail('Should throw InsufficientTriviaQuestionsException');
      } on InsufficientTriviaQuestionsException catch (e) {
        expect(e.toString(), contains('تجاوز حد الاستخدام المتاح للذكاء الاصطناعي'));
      }
    });
  });
}
