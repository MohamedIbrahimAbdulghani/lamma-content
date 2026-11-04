// Lamma - by Mohamed Ibrahim

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_config.dart';
import '../models/bootstrap_data.dart';
import '../models/question_model.dart';
import '../services/ai_question_service.dart';
import '../storage/local_storage.dart';

class QuestionsResponse {
  final List<QuestionModel> questions;
  final bool isExhausted;
  final int available;

  const QuestionsResponse({
    required this.questions,
    required this.isExhausted,
    required this.available,
  });
}

class ApiClient {
  final Dio _dio;
  final LocalStorage _storage;

  ApiClient(this._storage, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Device-Id'] = _storage.getDeviceId();
          return handler.next(options);
        },
      ),
    );
  }

  Dio get dio => _dio;

  // 1. Check content version
  Future<Map<String, dynamic>?> checkVersion() async {
    try {
      final response = await _dio.get('/content/version');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 2. Fetch full bootstrap for offline play
  Future<BootstrapData?> fetchBootstrap() async {
    try {
      final response = await _dio.get('/bootstrap');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return BootstrapData.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  // 3. Fetch trivia questions with no-repeat rule
  Future<QuestionsResponse?> fetchQuestions({
    String? categories,
    String? difficulty,
    int count = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{'count': count};
      if (categories != null && categories.isNotEmpty) {
        queryParams['categories'] = categories;
      }
      if (difficulty != null && difficulty.isNotEmpty) {
        queryParams['difficulty'] = difficulty;
      }

      final response = await _dio.get('/questions', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawList = data['data'] as List<dynamic>? ?? [];
        final questions = rawList
            .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final exhausted = data['exhausted'] as bool? ?? false;
        final available = data['available'] as int? ?? questions.length;

        return QuestionsResponse(
          questions: questions,
          isExhausted: exhausted,
          available: available,
        );
      }
    } catch (_) {}
    return null;
  }

  // 4. Mark questions as seen
  Future<bool> markQuestionsSeen(List<int> questionIds) async {
    if (questionIds.isEmpty) return true;
    try {
      final response = await _dio.post(
        '/questions/seen',
        data: {'question_ids': questionIds},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 5. Generate AI Content via Backend Proxy
  Future<List<Map<String, dynamic>>> generateAiContent({
    required String gameType,
    String? category,
    List<String>? categories,
    String? difficulty,
    int count = 20,
    List<String> excludeItems = const [],
    CancelToken? cancelToken,
  }) async {
    final payload = <String, dynamic>{
      'game_type': gameType,
      'count': count,
      'exclude_items': excludeItems,
    };
    if (category != null && category.isNotEmpty) {
      payload['category'] = category;
    }
    if (categories != null && categories.isNotEmpty) {
      payload['categories'] = categories;
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      payload['difficulty'] = difficulty;
    }

    try {
      final response = await _dio.post(
        '/content/generate',
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 35),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        dynamic rawData = response.data['data'];
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          rawData = rawData['items'];
        }
        final data = rawData is List<dynamic> ? rawData : <dynamic>[];
        return data.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const AiCancelledException();
      }

      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      String serverMessage = '';
      String? errorCode;
      String? debugSource;
      String? debugModel;

      if (responseData is Map<String, dynamic>) {
        serverMessage = responseData['message'] as String? ?? '';
        errorCode = responseData['error_code'] as String?;
        if (responseData['debug_info'] is Map<String, dynamic>) {
          debugSource = responseData['debug_info']['source'] as String?;
          debugModel = responseData['debug_info']['model'] as String?;
        }
      }

      String debugSuffix = '';
      if (kDebugMode && statusCode != null) {
        final modelPart = debugModel != null ? ', الموديل: $debugModel' : '';
        debugSuffix = ' [المصدر: ${debugSource ?? 'Backend'}$modelPart, الرمز: $statusCode${errorCode != null ? ' - $errorCode' : ''}]';
      }

      if (statusCode == 401) {
        throw AiInvalidKeyException(serverMessage.isNotEmpty ? '$serverMessage$debugSuffix' : 'مفتاح الذكاء الاصطناعي في الخادم غير صالح أو غير معرّف.$debugSuffix');
      }

      if (statusCode == 404) {
        throw AiServiceException(serverMessage.isNotEmpty ? '$serverMessage$debugSuffix' : 'موديل الذكاء الاصطناعي المطلوب غير متاح حالياً (404).$debugSuffix');
      }

      if (statusCode == 429) {
        throw AiRateLimitException(serverMessage.isNotEmpty ? '$serverMessage$debugSuffix' : 'تم تجاوز حد استخدام الذكاء الاصطناعي مؤقتاً (429). يرجى الانتظار بضع ثوانٍ.$debugSuffix');
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          statusCode == 504) {
        throw AiTimeoutException(serverMessage.isNotEmpty ? '$serverMessage$debugSuffix' : 'انتهت مهلة استلام الرد من خادم الذكاء الاصطناعي.$debugSuffix');
      }

      if (e.error is SocketException || e.type == DioExceptionType.connectionError) {
        throw AiNoInternetException('تعذر الاتصال بخادم اللعبة (${_dio.options.baseUrl}). يرجى التأكد من تشغيل السيرفر والاتصال بالشبكة.$debugSuffix');
      }

      throw AiServiceException(serverMessage.isNotEmpty ? '$serverMessage$debugSuffix' : 'فشل توليد المحتوى من الخادم (${statusCode ?? e.type}).$debugSuffix');
    }
  }

  // 6. Reset device history on server
  Future<bool> resetDeviceHistory() async {
    try {
      final response = await _dio.post('/history/reset');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 7. Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 8. AI Health check
  Future<Map<String, dynamic>?> checkAiHealth() async {
    try {
      final response = await _dio.get('/ai/health');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 9. Room Session: Create
  Future<bool> createRoomSession(String roomCode, {String gameMode = 'trivia'}) async {
    try {
      final response = await _dio.post('/rooms', data: {
        'room_code': roomCode,
        'game_mode': gameMode,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 10. Room Session: Join
  Future<bool> joinRoomSession(String roomCode) async {
    try {
      final response = await _dio.post('/rooms/$roomCode/join');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 11. Room Session: Leave
  Future<bool> leaveRoomSession(String roomCode) async {
    try {
      final response = await _dio.post('/rooms/$roomCode/leave');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 12. Next Trivia Question (Autonomous & Secure - No plain correct_index)
  Future<QuestionModel?> fetchNextRoomQuestion(
    String roomCode, {
    String? categories,
    String? difficulty,
    List<String> excludeHashes = const [],
    List<String> excludeAnswerHashes = const [],
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categories != null && categories.isNotEmpty) queryParams['categories'] = categories;
      if (difficulty != null && difficulty.isNotEmpty) queryParams['difficulty'] = difficulty;
      if (excludeHashes.isNotEmpty) queryParams['exclude_hashes'] = excludeHashes;
      if (excludeAnswerHashes.isNotEmpty) queryParams['exclude_answer_hashes'] = excludeAnswerHashes;

      final response = await _dio.get(
        '/rooms/$roomCode/next-question',
        queryParameters: queryParams,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return QuestionModel.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('fetchNextRoomQuestion error: $e');
    }
    return null;
  }

  // 12.1 Next Trivia Questions Batch (Pre-buffering & Instant Play Again)
  Future<List<QuestionModel>> fetchNextRoomQuestionsBatch(
    String roomCode, {
    int count = 10,
    String? categories,
    String? difficulty,
    List<String> excludeHashes = const [],
    List<String> excludeAnswerHashes = const [],
  }) async {
    try {
      final queryParams = <String, dynamic>{'count': count};
      if (categories != null && categories.isNotEmpty) queryParams['categories'] = categories;
      if (difficulty != null && difficulty.isNotEmpty) queryParams['difficulty'] = difficulty;
      if (excludeHashes.isNotEmpty) queryParams['exclude_hashes'] = excludeHashes;
      if (excludeAnswerHashes.isNotEmpty) queryParams['exclude_answer_hashes'] = excludeAnswerHashes;

      final response = await _dio.get(
        '/rooms/$roomCode/next-questions-batch',
        queryParameters: queryParams,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final rawData = response.data['data'];
        if (rawData is List) {
          return rawData.map((item) => QuestionModel.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('fetchNextRoomQuestionsBatch error: $e');
    }
    return [];
  }

  // 12.2 Next Charades Words Batch (Pre-buffering & Instant Play Again)
  Future<List<String>> fetchNextCharadesBatch(
    String roomCode, {
    int count = 15,
    String category = 'movies',
    List<String> excludeWords = const [],
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'count': count,
        'category': category,
      };
      if (excludeWords.isNotEmpty) queryParams['exclude_words'] = excludeWords;

      final response = await _dio.get(
        '/rooms/$roomCode/next-charades-batch',
        queryParameters: queryParams,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final rawData = response.data['data'];
        if (rawData is List) {
          return rawData.map((item) => (item['word_ar'] ?? '').toString()).where((w) => w.isNotEmpty).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // 12.3 Next Spy Rounds Batch (Pre-buffering & Instant Play Again)
  Future<List<Map<String, dynamic>>> fetchNextSpyBatch(
    String roomCode, {
    int rounds = 3,
    String packSlug = 'places',
  }) async {
    try {
      final response = await _dio.get(
        '/rooms/$roomCode/next-spy-batch',
        queryParameters: {'rounds': rounds, 'pack_slug': packSlug},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final list = response.data['data'] as List<dynamic>?;
        if (list != null) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  // 13. Grade Question on Backend
  Future<Map<String, dynamic>?> gradeRoomQuestion(
    String roomCode, {
    required int questionId,
    required int chosenIndex,
    required int timeRemaining,
    required int totalSeconds,
  }) async {
    try {
      final response = await _dio.post(
        '/rooms/$roomCode/grade-question',
        data: {
          'question_id': questionId,
          'chosen_index': chosenIndex,
          'time_remaining': timeRemaining,
          'total_seconds': totalSeconds,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 14. Next Spy Round (Homogeneous Word Group + 4 Choices for Spy)
  Future<Map<String, dynamic>?> fetchNextSpyRound(
    String roomCode, {
    String pack = 'places',
    String difficulty = 'medium',
    String? previousWord,
    List<String> seenWordHashes = const [],
  }) async {
    try {
      final queryParams = <String, dynamic>{'pack': pack, 'difficulty': difficulty};
      if (previousWord != null && previousWord.isNotEmpty) {
        queryParams['previous_word'] = previousWord;
      }
      if (seenWordHashes.isNotEmpty) {
        queryParams['seen_word_hashes'] = seenWordHashes;
      }

      final response = await _dio.get(
        '/rooms/$roomCode/next-spy-round',
        queryParameters: queryParams,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('fetchNextSpyRound error: $e');
    }
    return null;
  }

  // 15. Next Charades Word
  Future<String?> fetchNextCharadesWord(
    String roomCode, {
    String category = 'movies',
    List<String> excludeWords = const [],
  }) async {
    try {
      final queryParams = <String, dynamic>{'category': category};
      if (excludeWords.isNotEmpty) {
        queryParams['exclude_words'] = excludeWords;
      }

      final response = await _dio.get(
        '/rooms/$roomCode/next-charades',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['data']?['word_ar'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // 16. Report Inappropriate or Inaccurate Content
  Future<bool> reportContent({
    required String contentType,
    required int contentId,
    String? reason,
  }) async {
    try {
      final response = await _dio.post('/content/report', data: {
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason ?? 'بلاغ من لاعب',
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 17. Fetch Content Sync Status (No question text leaked)
  Future<Map<String, dynamic>?> fetchSyncStatus() async {
    try {
      final response = await _dio.get('/content/sync-status');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  // 18. Sync Offline History to Backend
  Future<bool> syncDeviceHistory({
    List<int> seenTriviaIds = const [],
    List<int> seenSpyGroupIds = const [],
    List<int> seenCharadesIds = const [],
  }) async {
    try {
      final response = await _dio.post('/content/sync-history', data: {
        'seen_trivia_ids': seenTriviaIds,
        'seen_spy_group_ids': seenSpyGroupIds,
        'seen_charades_ids': seenCharadesIds,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
