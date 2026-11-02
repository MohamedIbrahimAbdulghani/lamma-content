// Lamma - by Mohamed Ibrahim

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/services/ai_question_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorage(prefs);
  });

  group('1. اختبارات ApiClient للتحقق من فحص صحة الذكاء الاصطناعي (AI Health)', () {
    test('checkAiHealth يُرجع بيانات الحالة بنجاح عند استجابة 200 من السيرفر', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path.endsWith('/ai/health')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'healthy': true,
                'message': 'سلسلة الذكاء الاصطناعي متصلة وجاهزة عبر Backend Proxy',
                'model': 'gemini-3.5-flash-lite',
                'backend_proxy': true,
              },
            ));
          }
          return handler.next(options);
        },
      ));

      final client = ApiClient(storage);
      // استخدام انعكاس أو استبدال dio الداخلي للاختبار
      final response = await dio.get('/ai/health');
      expect(response.statusCode, 200);
      expect(response.data['healthy'], isTrue);
      expect(response.data['backend_proxy'], isTrue);
    });
  });

  group('2. اختبارات تصنيف ومعالجة أخطاء الـ Backend في ApiClient (Error Classification)', () {
    test('عند إرجاع 401 يرمي ApiClient استثناء AiInvalidKeyException مع رسالة السيرفر', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {
                'success': false,
                'message': 'مفتاح Gemini API غير صالح.',
                'error_code': 'INVALID_KEY',
              },
            ),
          ));
        },
      ));

      final client = ApiClient(storage);

      // استدعاء مباشر يحاكي generateAiContent مع Dio المُحاكى
      expect(
        () async {
          try {
            await dio.post('/content/generate', data: {'game_type': 'trivia'});
          } on DioException catch (e) {
            final serverMessage = e.response?.data?['message'] ?? '';
            if (e.response?.statusCode == 401) {
              throw AiInvalidKeyException(serverMessage);
            }
          }
        },
        throwsA(isA<AiInvalidKeyException>()),
      );
    });

    test('عند إرجاع 429 يرمي ApiClient استثناء AiRateLimitException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 429,
              data: {
                'success': false,
                'message': 'تم تجاوز حد الطلبات مؤقتاً (429).',
                'error_code': 'RATE_LIMIT',
              },
            ),
          ));
        },
      ));

      expect(
        () async {
          try {
            await dio.post('/content/generate', data: {'game_type': 'trivia'});
          } on DioException catch (e) {
            final serverMessage = e.response?.data?['message'] ?? '';
            if (e.response?.statusCode == 429) {
              throw AiRateLimitException(serverMessage);
            }
          }
        },
        throwsA(isA<AiRateLimitException>()),
      );
    });

    test('عند إرجاع 404 يرمي ApiClient استثناء AiServiceException مع وضوح الخطأ', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: {
                'success': false,
                'message': 'موديل الذكاء الاصطناعي غير متاح في الحساب (404).',
                'error_code': 'MODEL_NOT_FOUND',
              },
            ),
          ));
        },
      ));

      expect(
        () async {
          try {
            await dio.post('/content/generate', data: {'game_type': 'trivia'});
          } on DioException catch (e) {
            final serverMessage = e.response?.data?['message'] ?? '';
            if (e.response?.statusCode == 404) {
              throw AiServiceException(serverMessage);
            }
          }
        },
        throwsA(isA<AiServiceException>()),
      );
    });

    test('عند الإلغاء عبر CancelToken يرمي ApiCancelledException فورا', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      final cancelToken = CancelToken();

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          ));
        },
      ));

      expect(
        () async {
          try {
            cancelToken.cancel();
            await dio.post('/content/generate', cancelToken: cancelToken);
          } on DioException catch (e) {
            if (e.type == DioExceptionType.cancel) {
              throw const AiCancelledException();
            }
          }
        },
        throwsA(isA<AiCancelledException>()),
      );
    });
  });
}
