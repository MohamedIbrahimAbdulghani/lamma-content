// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/question_model.dart';

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

class AiInvalidResponseException extends AiException {
  const AiInvalidResponseException([super.message = 'تعذر قراءة رد الذكاء الاصطناعي بشكل صحيح.']);
}

class AiServiceException extends AiException {
  const AiServiceException([super.message = 'حدث خطأ أثناء التواصل مع الذكاء الاصطناعي.']);
}

/// طبقة موحدة لجميع نداءات الذكاء الاصطناعي (Google AI Studio Gemini)
class AiQuestionService {
  /// اسم الموديل الرسمي غير المهجور من توثيق Google AI Studio
  static const String kDefaultGeminiModel = 'gemini-2.5-flash';

  final Dio _dio;
  final String? _injectedApiKey;
  final String? _injectedModel;

  AiQuestionService({
    Dio? dio,
    String? apiKey,
    String? model,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 40),
                headers: {
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _injectedApiKey = apiKey,
        _injectedModel = model;

  String _getApiKey() {
    final key = _injectedApiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.trim().isEmpty) {
      throw const AiServiceException('مفتاح Gemini API غير معين في ملف .env');
    }
    return key.trim();
  }

  String _getModel() {
    return _injectedModel ?? dotenv.env['GEMINI_MODEL'] ?? kDefaultGeminiModel;
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
    int maxRetries = 3,
  }) async {
    final selectedCategories = categories != null && categories.isNotEmpty
        ? categories
        : (category != null && category.isNotEmpty && category != 'all' ? [category] : <String>[]);

    final prompt = _buildTriviaPrompt(
      count: count,
      categories: selectedCategories,
      difficulty: difficulty,
      specificTopic: specificTopic,
      avoidTopics: avoidTopics.take(30).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(prompt, maxRetries: maxRetries);

    final questions = <QuestionModel>[];
    for (var i = 0; i < rawJsonList.length; i++) {
      final item = rawJsonList[i];
      if (item is! Map<String, dynamic>) continue;

      final promptAr = (item['prompt_ar'] ?? item['question_ar'] ?? item['prompt']) as String?;
      final optionsRaw = item['options'] as List<dynamic>?;
      final correctIndex = item['correct_index'] as int? ?? (item['answer_index'] as int? ?? 0);
      final itemCategory = (item['category_slug'] ?? item['category'] ?? (selectedCategories.isNotEmpty ? selectedCategories.first : 'general')).toString();
      final itemDifficulty = (item['difficulty'] ?? difficulty ?? 'medium').toString();
      final explanation = item['explanation_ar'] as String?;

      if (promptAr == null || promptAr.trim().length < 5) continue;
      if (optionsRaw == null || optionsRaw.length != 4) continue;

      final options = optionsRaw.map((e) => e.toString().trim()).toList();
      // تأكد أن الخيارات الأربعة فريدة وغير متطابقة
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
    int maxRetries = 3,
  }) async {
    final prompt = _buildSpyPrompt(
      count: count,
      category: category,
      specificTopic: specificTopic,
      avoidWords: avoidWords.take(30).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(prompt, maxRetries: maxRetries);

    final words = <String>[];
    for (final item in rawJsonList) {
      if (item is Map<String, dynamic>) {
        final w = (item['word_ar'] ?? item['word'] ?? item['place_ar'] ?? item['name_ar']) as String?;
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
  // 3. توليد كلمات مثّل ومتتكلمش (CHARADES)
  // ==========================================

  Future<List<String>> generateCharadesWords({
    required int count,
    String? category,
    String? specificTopic,
    List<String> avoidWords = const [],
    int maxRetries = 3,
  }) async {
    final prompt = _buildCharadesPrompt(
      count: count,
      category: category,
      specificTopic: specificTopic,
      avoidWords: avoidWords.take(30).toList(),
    );

    final rawJsonList = await _callGeminiWithRetry(prompt, maxRetries: maxRetries);

    final words = <String>[];
    for (final item in rawJsonList) {
      if (item is Map<String, dynamic>) {
        final w = (item['word_ar'] ?? item['title_ar'] ?? item['word']) as String?;
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

  Future<List<dynamic>> _callGeminiWithRetry(String promptText, {int maxRetries = 3}) async {
    final apiKey = _getApiKey();
    final model = _getModel();
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

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
      },
    };

    int attempt = 0;
    while (attempt <= maxRetries) {
      attempt++;
      try {
        final response = await _dio.post(url, data: body);

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw const AiInvalidResponseException('لم يُرجع الذكاء الاصطناعي أي رد صالح.');
          }

          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          final rawText = parts?[0]?['text'] as String? ?? '';

          final parseStopwatch = Stopwatch()..start();
          final parsed = await _parseJsonArray(rawText);
          parseStopwatch.stop();
          debugPrint('[AI_BENCHMARK] JSON Parsing (Isolate/Compute) took: ${parseStopwatch.elapsedMilliseconds}ms');

          return parsed;
        } else {
          throw AiServiceException('استجابة غير متوقعة من السيرفر: ${response.statusCode}');
        }
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;

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
- تجنب تماماً تكرار أو محاكاة هذه المواضيع أو الأسئلة السابقة: $avoidDesc
- تنويع واسع جداً وعدم التكرار الداخلي.
- كل سؤال له 4 اختيارات مختلفة تماماً، وإجابة واحدة فقط صحيحة برقم الفهرس (0 إلى 3).
- ممنوع أي محتوى غير لائق أو مسيء أو مخل.

صيغة الرد المطلوبة JSON فقط على شكل مصفوفة كائنات بدون أي نصوص خارج الـ JSON:
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
المطلوب توليد دفعة من $count كلمة/مكان سري مشهور ومعروف للمصريين.
- القسم: $catDesc
- $topicDesc
- تجنب الكلمات التالية: $avoidDesc
- يجب أن تكون الكلمات محددة ومألوفة لجميع اللاعبين (مثل: كوبري قصر النيل، المتحف المصري، قهوة الفيشاوي، محطة الرمل).

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
المطلوب توليد $count عبارة أو كلمة ممتعة وقابلة للتمثيل الحركي بوضوح.
- القسم: $catDesc (أفلام، مسلسلات، أمثال شعبية، مهن، أشياء).
- $topicDesc
- تجنب العبارات التالية: $avoidDesc
- يجب أن تكون الجمل حركية وتفاعلية وسهلة الفهم للجمهور المصري والعربي.

أخرج الرد كـ JSON فقط مصفوفة كائنات:
[
  {"word_ar": "صعيدي في الجامعة الأمريكية"}
]
''';
  }
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
      // خذ أول قائمة متوفرة داخل الكائن
      for (final val in decoded.values) {
        if (val is List) return val;
      }
    }
  } catch (_) {}

  throw const AiInvalidResponseException('فشل تحليل بيانات JSON المستلمة.');
}
