// Lamma - by Mohamed Ibrahim

import 'package:dio/dio.dart';
import '../../core/constants/api_config.dart';
import '../models/bootstrap_data.dart';
import '../models/question_model.dart';
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

  ApiClient(this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
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

  // 5. Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
