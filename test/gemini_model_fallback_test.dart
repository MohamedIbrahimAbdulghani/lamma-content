// Lamma - by Mohamed Ibrahim
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/services/ai_question_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. اختبارات تجريد اسم الموديل وبناء العنوان (Sanitization & URL Construction)', () {
    test('تجريد بادئة models/ والمسافات الزائدة بدقة', () {
      expect(AiQuestionService.sanitizeModelName('gemini-3.5-flash-lite'), 'gemini-3.5-flash-lite');
      expect(AiQuestionService.sanitizeModelName('models/gemini-3.5-flash-lite'), 'gemini-3.5-flash-lite');
      expect(AiQuestionService.sanitizeModelName('  models/gemini-3.5-flash-lite  '), 'gemini-3.5-flash-lite');
      expect(AiQuestionService.sanitizeModelName('models/models/gemini-3.5-flash-lite'), 'gemini-3.5-flash-lite');
    });

    test('بناء عنوان generateContent يضع models/ مرة واحدة فقط ولا يكررها أبداً', () {
      const apiKey = 'TEST_KEY_123';

      final url1 = AiQuestionService.buildGenerateContentUrl('gemini-3.5-flash-lite', apiKey);
      expect(url1, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=TEST_KEY_123');

      // عند إدخال اسم موديل يحتوي على models/ (مثل ردود Google API)
      final url2 = AiQuestionService.buildGenerateContentUrl('models/gemini-3.5-flash-lite', apiKey);
      expect(url2, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=TEST_KEY_123');
      expect(url2.contains('models/models/'), isFalse);

      // التأكد من عدم تكرار البادئة
      final matches = RegExp(r'models/').allMatches(url2);
      expect(matches.length, 1);
    });

    test('الموديل الأساسي الافتراضي في ثابت واحد هو gemini-3.5-flash-lite', () {
      expect(AiQuestionService.kDefaultGeminiModel, 'gemini-3.5-flash-lite');
      expect(AiQuestionService.kDefaultGeminiModel.startsWith('models/'), isFalse);
    });

    test('القائمة الاحتياطية مرتبة وفق المطلوب بدقة وبدون أي موديلات 2.5', () {
      expect(AiQuestionService.kFallbackModels, [
        'gemini-3.5-flash-lite',
        'gemini-flash-lite-latest',
        'gemini-flash-latest',
      ]);
      expect(AiQuestionService.kFallbackModels.any((m) => m.contains('2.5')), isFalse);
    });
  });

  group('2. اختبار فلترة الموديلات واستبعاد tts/image/lyria/transcribe (Model Filtering)', () {
    test('استبعاد الموديلات الصوتية والمرئية واختيار الموديل السريع الفعال', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path.contains('/v1beta/models')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'models': [
                  {
                    'name': 'models/gemini-flash-image',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/gemini-preview-tts',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/gemini-3.5-transcribe',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/gemini-embedding-001',
                    'supportedGenerationMethods': ['embedContent'],
                  },
                  {
                    'name': 'models/gemini-3.5-flash-lite',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/gemini-flash-latest',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              },
            ));
          }
          return handler.next(options);
        },
      ));

      final aiService = AiQuestionService(
        dio: dio,
        storage: storage,
        apiKey: 'DUMMY_KEY',
      );

      final selectedModel = await aiService.discoverAndSelectBestModel();

      // يجب أن يتجاهل flash-image و tts و lyria و transcribe ويختار gemini-3.5-flash-lite
      expect(selectedModel, 'gemini-3.5-flash-lite');
    });
  });

  group('3. اختبار المعالجة التلقائية لخطأ 404 وإعادة المحاولة بالبديل (404 Fallback Recovery)', () {
    test('عند إرجاع 404 للموديل الحالي، يتم اكتشاف الموديل الصالح تلقائياً وإتمام الطلب بنجاح', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);

      int postAttempts = 0;
      final dio = Dio();

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // استعلام الموديلات عند 404
          if (options.uri.path.contains('/v1beta/models') && options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'models': [
                  {
                    'name': 'models/gemini-3.5-flash-lite',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/gemini-flash-latest',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              },
            ));
          }

          // نداء generateContent
          if (options.method == 'POST') {
            postAttempts++;
            // أول محاولة: الموديل غير موجود ويرجع 404
            if (options.uri.path.contains('non-existent-model')) {
              return handler.reject(DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'error': {'code': 404, 'message': 'models/non-existent-model is not found'}},
                ),
              ));
            }

            // المحاولة الثانية بعد الـ Fallback بالموديل المكتشف gemini-3.5-flash-lite
            if (options.uri.path.contains('gemini-3.5-flash-lite')) {
              final sampleJson = jsonEncode([
                {
                  'prompt_ar': 'ما هي عاصمة أم الدنيا مصر؟',
                  'options': ['القاهرة', 'الإسكندرية', 'الجيزة', 'أسوان'],
                  'correct_index': 0,
                  'category': 'general',
                  'difficulty': 'easy',
                }
              ]);

              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': sampleJson}
                        ]
                      }
                    }
                  ]
                },
              ));
            }
          }

          return handler.next(options);
        },
      ));

      final aiService = AiQuestionService(
        dio: dio,
        storage: storage,
        apiKey: 'DUMMY_KEY',
        model: 'non-existent-model',
      );

      final questions = await aiService.generateTriviaQuestions(count: 1);

      expect(questions.length, 1);
      expect(questions.first.promptAr, 'ما هي عاصمة أم الدنيا مصر؟');
      expect(questions.first.options[questions.first.correctIndex], 'القاهرة');
      expect(postAttempts, 2);
    });
  });
}
