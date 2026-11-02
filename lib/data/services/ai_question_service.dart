// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/question_model.dart';
import '../storage/local_storage.dart';

/// استثناءات مخصصة للتواصل مع الذكاء الاصطناعي مع رسائل عربية واضحة
sealed class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

class AiNoInternetException extends AiException {
  const AiNoInternetException([super.message = 'لا يوجد اتصال بالإنترنت. يرجى التأكد من اتصالك والمحاولة مرة أخرى.']);
}

class AiTimeoutException extends AiException {
  const AiTimeoutException([super.message = 'انتهت مهلة الاتصال بالذكاء الاصطناعي. يرجى المحاولة ثانية.']);
}

class AiRateLimitException extends AiException {
  const AiRateLimitException([super.message = 'تم تجاوز حد الطلبات مؤقتاً (429). يرجى الانتظار بضع ثوانٍ ثم المحاولة.']);
}

class AiInvalidKeyException extends AiException {
  const AiInvalidKeyException([super.message = 'مفتاح Gemini API غير صالح أو غير معرّف بشكل صحيح.']);
}

class AiInvalidResponseException extends AiException {
  const AiInvalidResponseException([super.message = 'تعذر قراءة رد الذكاء الاصطناعي بشكل صحيح.']);
}

class AiCancelledException extends AiException {
  const AiCancelledException([super.message = 'تم إلغاء عملية التوليد.']);
}

class AiServiceException extends AiException {
  const AiServiceException([super.message = 'حدث خطأ أثناء التواصل مع الذكاء الاصطناعي.']);
}

/// طبقة موحدة لجميع نداءات الذكاء الاصطناعي (Google AI Studio Gemini)
class AiQuestionService {
  /// اسم الموديل الأساسي في ثابت واحد بدون بادئة models/
  static const String kDefaultGeminiModel = 'gemini-3.5-flash-lite';

  /// قائمة الموديلات الاحتياطية مرتبة حسب الأفضلية والسرعة
  static const List<String> kFallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  /// الكلمات الدلالية للموديلات غير المناسبة لاستبعادها (الصوت، الصور، الفيديو، والروبوتات)
  static const List<String> kExcludedModelKeywords = [
    'tts',
    'image',
    'lyria',
    'transcribe',
    'robotics',
    'computer-use',
    'embedding',
    'aqa',
  ];

  final Dio _dio;
  final LocalStorage? _storage;
  final String? _injectedApiKey;
  final String? _injectedModel;
  String? _activeModel;

  AiQuestionService({
    Dio? dio,
    LocalStorage? storage,
    String? apiKey,
    String? model,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _storage = storage,
        _injectedApiKey = apiKey,
        _injectedModel = model;

  /// تجريد أي بادئة models/ أو مسافات من اسم الموديل
  static String sanitizeModelName(String rawModel) {
    var cleaned = rawModel.trim();
    while (cleaned.startsWith('models/')) {
      cleaned = cleaned.substring('models/'.length).trim();
    }
    return cleaned;
  }

  /// بناء عنوان طلب توليد المحتوى generateContent مع ضمان إضافة models/ مرة واحدة فقط وبدون تكرار
  static String buildGenerateContentUrl(String rawModel, String apiKey) {
    final sanitized = sanitizeModelName(rawModel);
    return 'https://generativelanguage.googleapis.com/v1beta/models/$sanitized:generateContent?key=$apiKey';
  }

  /// بناء عنوان استعلام قائمة الموديلات GET /v1beta/models
  static String buildModelsListUrl(String apiKey) {
    return 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';
  }

  bool get hasApiKey {
    final key = _injectedApiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    return key.trim().isNotEmpty;
  }

  String _getApiKey() {
    final key = _injectedApiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.trim().isEmpty) {
      throw const AiInvalidKeyException('مفتاح Gemini API غير معين في ملف .env');
    }
    return key.trim();
  }

  String _getModel() {
    if (_activeModel != null && _activeModel!.trim().isNotEmpty) {
      return sanitizeModelName(_activeModel!);
    }
    if (_injectedModel != null && _injectedModel!.trim().isNotEmpty) {
      return sanitizeModelName(_injectedModel!);
    }
    final envModel = dotenv.env['GEMINI_MODEL'];
    if (envModel != null && envModel.trim().isNotEmpty) {
      return sanitizeModelName(envModel);
    }
    return kDefaultGeminiModel;
  }

  /// عند 404 نقرأ GET /v1beta/models ونختار أول Flash متاح يدعم generateContent
  Future<String> discoverAndSelectBestModel({CancelToken? cancelToken}) async {
    final apiKey = _getApiKey();
    final url = buildModelsListUrl(apiKey);

    try {
      final response = await _dio.get(
        url,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final modelsList = data['models'] as List<dynamic>? ?? [];

        final validFlashModels = <String>[];

        for (final item in modelsList) {
          if (item is! Map<String, dynamic>) continue;
          final rawName = item['name'] as String? ?? '';
          final cleanName = sanitizeModelName(rawName);
          final lower = cleanName.toLowerCase();

          // التحقق من دعم توليد المحتوى
          final methods = (item['supportedGenerationMethods'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (!methods.contains('generateContent')) continue;

          // التأكد من أنه موديل Flash لتسريع الاستجابة
          if (!lower.contains('flash')) continue;

          // تجنب موديلات الصوت والصور والموديلات المتخصصة
          final isExcluded = kExcludedModelKeywords.any((kw) => lower.contains(kw));
          if (isExcluded) continue;

          validFlashModels.add(cleanName);
        }

        // 1. هل الموديل الأساسي متاح في الحساب؟
        if (validFlashModels.contains(kDefaultGeminiModel)) {
          await _persistSelectedModel(kDefaultGeminiModel);
          return kDefaultGeminiModel;
        }

        // 2. هل أحد الموديلات الاحتياطية الثابتة متاح حسب الأولوية؟
        for (final fallback in kFallbackModels) {
          if (validFlashModels.contains(fallback)) {
            await _persistSelectedModel(fallback);
            return fallback;
          }
        }

        // 3. اختيار أول موديل Flash صالح من القائمة المكتشفة ديناميكياً
        if (validFlashModels.isNotEmpty) {
          final selected = validFlashModels.first;
          await _persistSelectedModel(selected);
          return selected;
        }
      }
    } catch (_) {
      // في حالة تعذر جلب القائمة، نعتمد على أول بديل في القائمة الاحتياطية الثابتة
    }

    final fallback = kFallbackModels.first;
    await _persistSelectedModel(fallback);
    return fallback;
  }

  Future<void> _persistSelectedModel(String model) async {
    _activeModel = sanitizeModelName(model);
  }

  // ==========================================
  // 1. توليد أسئلة تحدي الشلة (TRIVIA)
  // ==========================================

  Future<List<QuestionModel>> generateTriviaQuestions({
    required int count,
    String? category,
    List<String>? categories,
    String? difficulty,
    String? specificTopic,
    List<String> avoidTopics = const [],
    int maxRetries = 2,
    CancelToken? cancelToken,
    void Function(List<QuestionModel> batch)? onBatchReceived,
  }) async {
    final selectedCategories = categories != null && categories.isNotEmpty
        ? categories
        : (category != null && category.isNotEmpty && category != 'all' ? [category] : <String>[]);

    // إذا كان العدد كبيراً نقسمه إلى دفعات صغيرة متوازية (5-7 عناصر في الدفعة، بحد أقصى 3 طلبات متزامنة)
    if (count > 7) {
      final batchSizes = <int>[];
      int remaining = count;
      while (remaining > 0) {
        final currentBatch = remaining > 7 ? 6 : remaining;
        batchSizes.add(currentBatch);
        remaining -= currentBatch;
        if (batchSizes.length >= 3 && remaining > 0) {
          batchSizes[batchSizes.length - 1] += remaining;
          break;
        }
      }

      final allQuestions = <QuestionModel>[];
      final tasks = batchSizes.map((bCount) async {
        final subPrompt = _buildTriviaPrompt(
          count: bCount,
          categories: selectedCategories,
          difficulty: difficulty,
          specificTopic: specificTopic,
          avoidTopics: avoidTopics.take(15).toList(),
        );

        final rawJsonList = await _callGeminiWithRetry(
          subPrompt,
          maxRetries: maxRetries,
          maxOutputTokens: 1400,
          cancelToken: cancelToken,
          responseSchema: _triviaResponseSchema,
        );

        final batchQuestions = _parseTriviaQuestions(
          rawJsonList,
          selectedCategories: selectedCategories,
          fallbackDifficulty: difficulty,
        );

        if (batchQuestions.isNotEmpty) {
          onBatchReceived?.call(batchQuestions);
        }
        return batchQuestions;
      });

      final results = await Future.wait(tasks);
      for (final batch in results) {
        allQuestions.addAll(batch);
      }
      return allQuestions;
    }

    // دفعة واحدة للكميات الصغيرة (<= 7)
    final prompt = _buildTriviaPrompt(
      count: count,
      categories: selectedCategories,
      difficulty: difficulty,
      specificTopic: specificTopic,
      avoidTopics: avoidTopics.take(15).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(
      prompt,
      maxRetries: maxRetries,
      maxOutputTokens: 1400,
      cancelToken: cancelToken,
      responseSchema: _triviaResponseSchema,
    );

    final questions = _parseTriviaQuestions(
      rawJsonList,
      selectedCategories: selectedCategories,
      fallbackDifficulty: difficulty,
    );

    if (questions.isNotEmpty) {
      onBatchReceived?.call(questions);
    }
    return questions;
  }

  List<QuestionModel> _parseTriviaQuestions(
    List<dynamic> rawJsonList, {
    required List<String> selectedCategories,
    String? fallbackDifficulty,
  }) {
    final questions = <QuestionModel>[];
    for (var i = 0; i < rawJsonList.length; i++) {
      final item = rawJsonList[i];
      if (item is! Map<String, dynamic>) continue;

      final promptAr = (item['prompt_ar'] ?? item['question_ar'] ?? item['prompt']) as String?;
      final optionsRaw = item['options'] as List<dynamic>?;
      final correctIndex = item['correct_index'] as int? ?? (item['answer_index'] as int? ?? 0);
      final itemCategory = (item['category_slug'] ?? item['category'] ?? (selectedCategories.isNotEmpty ? selectedCategories.first : 'general')).toString();
      final itemDifficulty = (item['difficulty'] ?? fallbackDifficulty ?? 'medium').toString();
      final explanation = item['explanation_ar'] as String?;

      if (promptAr == null || promptAr.trim().length < 5) continue;
      if (optionsRaw == null || optionsRaw.length != 4) continue;

      final options = optionsRaw.map((e) => e.toString().trim()).toList();
      if (options.toSet().length != 4 || options.any((o) => o.isEmpty)) continue;
      if (correctIndex < 0 || correctIndex > 3) continue;

      questions.add(QuestionModel(
        id: -1 * (DateTime.now().millisecondsSinceEpoch % 1000000 + i + 1),
        categoryId: 1,
        categorySlug: itemCategory,
        type: 'mcq',
        promptAr: promptAr.trim(),
        options: options,
        correctIndex: correctIndex,
        difficulty: itemDifficulty,
        explanationAr: explanation?.trim(),
        source: 'gemini',
      ));
    }
    return questions;
  }

  // ==========================================
  // 2. توليد كلمات مين الجاسوس (SPY)
  // ==========================================

  Future<List<String>> generateSpyWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 2,
    CancelToken? cancelToken,
    void Function(List<String> batch)? onBatchReceived,
  }) async {
    if (count > 10) {
      final b1 = (count / 2).ceil();
      final b2 = count - b1;
      final tasks = [b1, b2].map((bCount) async {
        final subPrompt = _buildSpyPrompt(
          count: bCount,
          category: category,
          specificTopic: specificTopic,
          avoidWords: avoidWords.take(15).toList(),
        );

        final rawJsonList = await _callGeminiWithRetry(
          subPrompt,
          maxRetries: maxRetries,
          maxOutputTokens: 600,
          cancelToken: cancelToken,
          responseSchema: _wordsResponseSchema,
        );

        final words = _parseWords(rawJsonList);
        if (words.isNotEmpty) onBatchReceived?.call(words);
        return words;
      });

      final results = await Future.wait(tasks);
      final combined = <String>[];
      for (final r in results) {
        combined.addAll(r);
      }
      return combined;
    }

    final prompt = _buildSpyPrompt(
      count: count,
      category: category,
      specificTopic: specificTopic,
      avoidWords: avoidWords.take(15).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(
      prompt,
      maxRetries: maxRetries,
      maxOutputTokens: 600,
      cancelToken: cancelToken,
      responseSchema: _wordsResponseSchema,
    );

    final words = _parseWords(rawJsonList);
    if (words.isNotEmpty) onBatchReceived?.call(words);
    return words;
  }

  // ==========================================
  // 3. توليد كلمات مثّل ومتتكلمش (CHARADES)
  // ==========================================

  Future<List<String>> generateCharadesWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 2,
    CancelToken? cancelToken,
    void Function(List<String> batch)? onBatchReceived,
  }) async {
    if (count > 10) {
      final b1 = (count / 2).ceil();
      final b2 = count - b1;
      final tasks = [b1, b2].map((bCount) async {
        final subPrompt = _buildCharadesPrompt(
          count: bCount,
          category: category,
          specificTopic: specificTopic,
          avoidWords: avoidWords.take(15).toList(),
        );

        final rawJsonList = await _callGeminiWithRetry(
          subPrompt,
          maxRetries: maxRetries,
          maxOutputTokens: 600,
          cancelToken: cancelToken,
          responseSchema: _wordsResponseSchema,
        );

        final words = _parseWords(rawJsonList);
        if (words.isNotEmpty) onBatchReceived?.call(words);
        return words;
      });

      final results = await Future.wait(tasks);
      final combined = <String>[];
      for (final r in results) {
        combined.addAll(r);
      }
      return combined;
    }

    final prompt = _buildCharadesPrompt(
      count: count,
      category: category,
      specificTopic: specificTopic,
      avoidWords: avoidWords.take(15).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(
      prompt,
      maxRetries: maxRetries,
      maxOutputTokens: 600,
      cancelToken: cancelToken,
      responseSchema: _wordsResponseSchema,
    );

    final words = _parseWords(rawJsonList);
    if (words.isNotEmpty) onBatchReceived?.call(words);
    return words;
  }

  List<String> _parseWords(List<dynamic> rawJsonList) {
    final words = <String>[];
    for (final item in rawJsonList) {
      if (item is Map<String, dynamic>) {
        final w = (item['word_ar'] ?? item['word'] ?? item['place_ar'] ?? item['title_ar']) as String?;
        if (w != null && w.trim().isNotEmpty) {
          words.add(w.trim());
        }
      } else if (item is String && item.trim().isNotEmpty) {
        words.add(item.trim());
      }
    }
    return words;
  }

  // ==========================================
  // استدعاء Gemini API مع Exponential Backoff و JSON Mode
  // ==========================================

  Future<List<dynamic>> _callGeminiWithRetry(
    String promptText, {
    int maxRetries = 2,
    int maxOutputTokens = 1500,
    CancelToken? cancelToken,
    Map<String, dynamic>? responseSchema,
  }) async {
    final apiKey = _getApiKey();
    bool hasAttemptedDiscoveryOn404 = false;

    int attempt = 0;
    while (attempt <= maxRetries) {
      attempt++;
      final currentModel = _getModel();
      final url = buildGenerateContentUrl(currentModel, apiKey);

      final body = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': promptText},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
          'maxOutputTokens': maxOutputTokens,
          'thinkingConfig': {
            'thinkingBudget': 0,
          },
          if (responseSchema != null) 'responseSchema': responseSchema,
        },
      };

      try {
        final response = await _dio.post(
          url,
          data: body,
          cancelToken: cancelToken,
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw const AiInvalidResponseException('لم يُرجع الذكاء الاصطناعي أي رد صالح.');
          }

          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          final rawText = parts?[0]?['text'] as String? ?? '';

          return await _parseJsonArray(rawText);
        } else {
          throw AiServiceException('استجابة غير متوقعة من السيرفر: ${response.statusCode}');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          throw const AiCancelledException();
        }

        final statusCode = e.response?.statusCode;

        // معالجة 404 (الموديل غير موجود أو تغير اسمه): نقرأ الموديلات المتاحة ونختار البديل فوراً
        if (statusCode == 404 && !hasAttemptedDiscoveryOn404) {
          hasAttemptedDiscoveryOn404 = true;
          // مسح أي موديل قديم محفوظ تسبب في الـ 404
          _activeModel = null;
          try {
            final fallbackModel = await discoverAndSelectBestModel(cancelToken: cancelToken);
            if (fallbackModel != currentModel) {
              attempt--; // لا تحتسب كمحاولة فاشلة بل تبديل موديل
              continue;
            }
          } catch (_) {
            // الاستمرار في الـ loop
          }
        }

        // مفتاح غير صالح أو مشكلة صلاحيات
        if (statusCode == 400 || statusCode == 403) {
          final errBody = e.response?.data?.toString() ?? '';
          if (errBody.contains('API_KEY_INVALID') || errBody.contains('not valid') || errBody.contains('KEY')) {
            throw const AiInvalidKeyException();
          }
          // إذا كان الخطأ بسبب thinkingConfig غير مدعوم في الموديل المختار
          if (errBody.contains('thinkingConfig') && body['generationConfig'] is Map) {
            final genConfig = body['generationConfig'] as Map<String, dynamic>;
            genConfig.remove('thinkingConfig');
            continue;
          }
        }

        // في حالة تجاوز حد الطلبات (429 Rate Limit) نطبق exponential backoff
        if (statusCode == 429) {
          if (attempt <= maxRetries) {
            final delayMs = (pow(2, attempt) * 1000).toInt() + Random().nextInt(500);
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          throw const AiRateLimitException();
        }

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          if (attempt <= maxRetries) {
            await Future.delayed(Duration(seconds: attempt));
            continue;
          }
          throw const AiTimeoutException();
        }

        if (e.error is SocketException || e.type == DioExceptionType.connectionError) {
          throw const AiNoInternetException();
        }

        throw AiServiceException('حدث خطأ في الاتصال بالخدمة (${statusCode ?? e.type})');
      } catch (e) {
        if (e is AiException) rethrow;
        throw AiServiceException('خطأ غير متوقع: $e');
      }
    }

    throw const AiServiceException('فشلت جميع محاولات توليد المحتوى.');
  }

  // تحليل النص واستخراج مصفوفة الـ JSON باستخدام compute في Isolate خلفي لمنع تجميد واجهة المستخدم
  Future<List<dynamic>> _parseJsonArray(String rawText) async {
    try {
      if (rawText.length > 300) {
        return await compute(_parseJsonArrayWorker, rawText);
      }
      return _parseJsonArrayWorker(rawText);
    } catch (e) {
      if (e is AiInvalidResponseException) rethrow;
      throw const AiInvalidResponseException('فشل تحليل بيانات JSON المستلمة.');
    }
  }

  // ==========================================
  // Prompts Generation
  // ==========================================

  String _buildTriviaPrompt({
    required int count,
    List<String> categories = const [],
    String? difficulty,
    String? specificTopic,
    List<String> avoidTopics = const [],
  }) {
    final catDesc = categories.isNotEmpty ? categories.join('، ') : 'متنوعة وشاملة';
    final diffDesc = difficulty != null && difficulty != 'all' ? difficulty : 'متنوع (سهل ومتوسط وحراق)';
    final avoidDesc = avoidTopics.isNotEmpty ? avoidTopics.join('، ') : 'لا يوجد';
    final topicDesc = specificTopic != null && specificTopic.trim().isNotEmpty
        ? 'التركيز الخاص على الموضوع التالي: "${specificTopic.trim()}".'
        : '';

    return '''
أنت صانع أسئلة خبير لألعاب الحفلات واللمة العائلية بالعامية المصرية الودودة.
المطلوب توليد دفعة مكونة من $count سؤال اختيار من متعدد لتحدي الشلة.

المعايير:
- الأقسام المطلوبة: $catDesc
- مستوى الصعوبة: $diffDesc
- اللهجة: مصرية عامية مفهومة، طريفة ومسلية، تناسب التجمعات والشباب.
- $topicDesc
- تجنب تماماً هذه المواضيع أو الأسئلة السابقة: $avoidDesc
- تنويع واسع جداً وعدم التكرار الداخلي.
- كل سؤال له 4 اختيارات مختلفة تماماً، وإجابة واحدة فقط صحيحة برقم الفهرس (0 إلى 3).
- ممنوع أي محتوى غير لائق أو مسيء أو مخل.

صيغة الرد المطلوبة JSON فقط مصفوفة كائنات:
[
  {
    "category_slug": "sports",
    "difficulty": "medium",
    "prompt_ar": "مين أكتر لاعب سجل أهداف في تاريخ الدوري المصري؟",
    "options": ["حسن الشاذلي", "حسام حسن", "محمود الخطيب", "محمد أبو تريكة"],
    "correct_index": 0,
    "explanation_ar": "حسن الشاذلي الهداف التاريخي للدوري برصيد 173 هدفاً"
  }
]
''';
  }

  String _buildSpyPrompt({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
  }) {
    final catDesc = category ?? 'places';
    final avoidDesc = avoidWords.isNotEmpty ? avoidWords.join('، ') : 'لا يوجد';
    final topicDesc = specificTopic != null && specificTopic.trim().isNotEmpty
        ? 'التركيز الخاص على الموضوع: "${specificTopic.trim()}".'
        : '';

    return '''
أنت صانع كلمات للعبة "مين الجاسوس" باللهجة والثقافة المصرية.
المطلوب توليد $count كلمة/مكان سري مشهور ومعروف للمصريين.
- القسم: $catDesc
- $topicDesc
- تجنب الكلمات التالية: $avoidDesc
- يجب أن تكون الكلمات محددة ومألوفة لجميع اللاعبين (مثل: كوبري قصر النيل، المتحف المصري، قهوة الفيشاوي).

أخرج الرد كـ JSON فقط مصفوفة كائنات:
[
  {"word_ar": "خان الخليلي"}
]
''';
  }

  String _buildCharadesPrompt({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
  }) {
    final catDesc = category ?? 'movies';
    final avoidDesc = avoidWords.isNotEmpty ? avoidWords.join('، ') : 'لا يوجد';
    final topicDesc = specificTopic != null && specificTopic.trim().isNotEmpty
        ? 'التركيز الخاص على الموضوع: "${specificTopic.trim()}".'
        : '';

    return '''
أنت صانع كلمات للعبة بدون كلام / مثّل ومتتكلمش المصرية.
المطلوب توليد $count عبارة أو كلمة ممتعة وقابلة للتمثيل الحركي بوضوح (حد أقصى 4 كلمات).
- القسم: $catDesc
- $topicDesc
- تجنب العبارات التالية: $avoidDesc
- يجب أن تكون الجمل حركية وتفاعلية وسهلة الفهم وتجنب المفاهيم المجردة أو السياسية.

أخرج الرد كـ JSON فقط مصفوفة كائنات:
[
  {"word_ar": "صعيدي في الجامعة الأمريكية"}
]
''';
  }

  // Schemas
  static const Map<String, dynamic> _triviaResponseSchema = {
    'type': 'ARRAY',
    'items': {
      'type': 'OBJECT',
      'properties': {
        'category_slug': {'type': 'STRING'},
        'difficulty': {'type': 'STRING'},
        'prompt_ar': {'type': 'STRING'},
        'options': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
        'correct_index': {'type': 'INTEGER'},
        'explanation_ar': {'type': 'STRING'},
      },
      'required': ['category_slug', 'difficulty', 'prompt_ar', 'options', 'correct_index'],
    },
  };

  static const Map<String, dynamic> _wordsResponseSchema = {
    'type': 'ARRAY',
    'items': {
      'type': 'OBJECT',
      'properties': {
        'word_ar': {'type': 'STRING'},
      },
      'required': ['word_ar'],
    },
  };
}

/// دالة عمل مستقلة في Isolate لتحليل الـ JSON
List<dynamic> _parseJsonArrayWorker(String rawText) {
  String clean = rawText.trim();
  if (clean.startsWith('```json')) {
    clean = clean.substring(7);
  } else if (clean.startsWith('```')) {
    clean = clean.substring(3);
  }
  if (clean.endsWith('```')) {
    clean = clean.substring(0, clean.length - 3);
  }
  clean = clean.trim();

  try {
    final decoded = jsonDecode(clean);
    if (decoded is List) {
      return decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('questions') && decoded['questions'] is List) {
        return decoded['questions'] as List<dynamic>;
      }
      if (decoded.containsKey('items') && decoded['items'] is List) {
        return decoded['items'] as List<dynamic>;
      }
      if (decoded.containsKey('words') && decoded['words'] is List) {
        return decoded['words'] as List<dynamic>;
      }
      for (final val in decoded.values) {
        if (val is List) return val;
      }
    }
  } catch (_) {}

  throw const AiInvalidResponseException('فشل تحليل بيانات JSON المستلمة.');
}
