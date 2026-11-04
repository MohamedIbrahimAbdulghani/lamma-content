import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/core/utils/category_localization.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('التحقق الفعلي: تصفير مخزون الأفلام وتوليد المحتوى الناقص تلقائياً', () {
    late LocalStorage storage;
    late ApiClient api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorage(prefs);
      api = ApiClient(storage, dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')));
    });

    test('1. تصفير قسم movies ثم العب تاني بإعداد 5 و10 أسئلة وقياس الأداء والمرفوض', () async {
      // تصفير مخزون قسم أفلام ومسلسلات بالكامل (وضع كل بنك الفولباك في سجل المشاهدة)
      for (final q in kFallbackTriviaQuestions) {
        if (q.categorySlug == 'movies') {
          final pHash = ArabicTextNormalizer.triviaQuestionHash(q.promptAr);
          await storage.markTriviaHashesSeen(promptHashes: [pHash]);
        }
      }

      int generatedCount = 0;
      int rejectedCount = 0;

      // محاكاة استجابة الـ backend الواقعية مع تنوع أفلام حقيقي
      final moviePromptsPool = [
        'من هو المخرج الذي أخرج فيلم الكيت كات بطولة محمود عبد العزيز عام 1991؟',
        'ما اسم الشخصية الأسطورية التي قدمها أحمد زكي في فيلم الهروب عام 1991؟',
        'من قام بتأليف موسيقى فيلم المصير للمخرج يوسف شاهين؟',
        'أي من الأفلام التالية فاز بالسعفة الذهبية في مهرجان كان السينمائي؟',
        'من هو كاتب سيناريو فيلم اللص والكلاب المقتبس عن رواية نجيب محفوظ؟',
        'ما اسم الفيلم الشهير الذي جمع سعاد حسني ورشدي أباظة عام 1970؟',
        'من جسد دور عتريس في الفيلم الخالد شيء من الخوف؟',
        'ما اسم المسرحية التي شهدت الظهور الأول لشخصية سكر هانم؟',
        'من أخرج فيلم باب الحديد وشارك بالتمثيل في دور قناوي؟',
        'أي عام تم عرض فيلم الزوجة الثانية للمخرج صلاح أبو سيف؟',
        'من هي بطلة فيلم دعاء الكروان بجانب النجم أحمد مظهر؟',
        'ما اسم فيلم أحمد زكي الذي تناول قصة حياة الموسيقار عبد الحليم حافظ؟',
        'من ألف وأخرج فيلم إسكندرية ليه الحائز على الدب الفضي ببرلين؟',
        'ما هي الشخصية التي لعبها عادل إمام في فيلم الإرهاب والكباب؟',
        'من لحن أغنية جانا الهوى للفنان الراحل عبد الحليم حافظ؟',
        'من أخرج فيلم عمارة يعقوبيان المقتبس عن رواية علاء الأسواني؟',
      ];

      api.dio.httpClientAdapter = MockDioAdapter((options) async {
        if (options.path.contains('/content/generate')) {
          final data = options.data as Map<String, dynamic>;
          final countReq = data['count'] as int? ?? 5;
          generatedCount += countReq;

          final items = <String>[];
          for (int i = 0; i < countReq; i++) {
            final p = moviePromptsPool[i % moviePromptsPool.length];
            items.add('''
            {
              "category_slug": "movies",
              "difficulty": "medium",
              "prompt_ar": "$p",
              "options": ["إجابة صحيحة للفيلم $i", "خيار بديل أ $i", "خيار بديل ب $i", "خيار بديل ج $i"],
              "correct_index": 0
            }
            ''');
          }
          final jsonStr = '{"status":"success","data":{"items":[${items.join(",")}]}}';
          return ResponseBody.fromString(jsonStr, 200, headers: {
            'content-type': ['application/json']
          });
        }
        return ResponseBody.fromString('{}', 200);
      });

      final contentService = GameContentService(api, storage);

      // تأكيد أن المتاح 0 سؤال قبل البدء
      final initialAvailable = contentService.getAvailableTriviaCount(
        categories: ['movies'],
        difficulty: 'medium',
      );
      expect(initialAvailable, equals(0));

      // تجربة إعداد 5 أسئلة
      final sw5 = Stopwatch()..start();
      final questions5 = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies'],
        difficulty: 'medium',
        allowAi: true,
      );
      sw5.stop();

      expect(questions5.length, equals(5));
      expect(questions5.every((q) => q.categorySlug == 'movies'), isTrue);

      // تجربة إعداد 10 أسئلة
      final sw10 = Stopwatch()..start();
      final questions10 = await contentService.getTriviaQuestions(
        count: 10,
        categories: ['movies'],
        difficulty: 'medium',
        allowAi: true,
      );
      sw10.stop();

      expect(questions10.length, equals(10));
      expect(questions10.every((q) => q.categorySlug == 'movies'), isTrue);

      final totalDelivered = questions5.length + questions10.length;
      final rejectionRate = generatedCount > 0 
          ? ((generatedCount - totalDelivered) / generatedCount * 100).toStringAsFixed(1)
          : '0.0';

      print('===========================================================');
      print('تقرير التحقق الفعلي لتصفير مخزون قسم أفلام:');
      print('1. المتاح المبدئي: $initialAvailable سؤال (مصفّر تماماً)');
      print('2. إعداد 5 أسئلة: الزمن حتى البدء = ${sw5.elapsedMilliseconds}ms، عدد الأسئلة = ${questions5.length}');
      print('3. إعداد 10 أسئلة: الزمن حتى البدء = ${sw10.elapsedMilliseconds}ms، عدد الأسئلة = ${questions10.length}');
      print('4. إجمالي الأسئلة المولّدة من الـ AI = $generatedCount');
      print('5. نسبة المرفوض (Rejection Rate) = $rejectionRate%');
      print('===========================================================');
    });

    test('2. التحقق من سيناريو انقطاع الإنترنت وظهور رسالة الصدق بالعربي', () async {
      // إعداد سيناريو أوفلاين (DioException connectionError)
      api.dio.httpClientAdapter = MockDioAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'Connection refused / No internet',
        );
      });

      final contentService = GameContentService(api, storage);

      try {
        await contentService.getTriviaQuestions(
          count: 5,
          categories: ['movies'],
          difficulty: 'medium',
          allowAi: true,
        );
        fail('كان يجب رمي InsufficientTriviaQuestionsException عند انقطاع الإنترنت');
      } on InsufficientTriviaQuestionsException catch (e) {
        print('===========================================================');
        print('رسالة الخطأ الصريحة عند انقطاع الإنترنت:');
        print('القسم بالعربي: ${e.category}');
        print('السبب الحقيقي: ${e.failureReason}');
        print('===========================================================');

        expect(e.category, equals('أفلام ومسلسلات'));
        expect(e.failureReason, contains('لا يوجد اتصال بالإنترنت'));
        expect(e.failureReason, contains('أفلام ومسلسلات'));
      }
    });
  });
}
