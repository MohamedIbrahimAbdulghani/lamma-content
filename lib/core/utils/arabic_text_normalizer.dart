// Lamma - by Mohamed Ibrahim

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class ArabicTextNormalizer {
  static const Map<String, String> _arabicDigitsMap = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  // Pre-compiled regular expressions for high performance without recompilation
  static final RegExp _tashkeelRegex = RegExp(r'[\u064B-\u0652\u0640]');
  static final RegExp _alifRegex = RegExp(r'[أإآٱ]');
  static final RegExp _punctuationRegex = RegExp(r'[،؟!.":؛\(\)\[\]«»\-_/\\#@!$%^&*+={}`~|<>]');
  static final RegExp _spacesRegex = RegExp(r'\s+');

  /// تطبيع النصوص العربية لمقارنة الكلمات ومنع التكرار بأعلى كفاءة وسرعة
  static String normalize(String text) {
    if (text.isEmpty) return '';

    String result = text;

    // 1. إزالة التشكيل والتنوين والشدة والسكون والتطويل (كشيدة)
    result = result.replaceAll(_tashkeelRegex, '');

    // 2. توحيد الألفات (أ، إ، آ، ٱ -> ا)
    result = result.replaceAll(_alifRegex, 'ا');

    // 3. توحيد التاء المربوطة (ة -> ه)
    result = result.replaceAll('ة', 'ه');

    // 4. توحيد الياء والألف المقصورة (ى -> ي)
    result = result.replaceAll('ى', 'ي');

    // 5. توحيد الأرقام الهندية/العربية المشرقية إلى أرقام قياسية (٠-٩ -> 0-9)
    _arabicDigitsMap.forEach((arDigit, enDigit) {
      if (result.contains(arDigit)) {
        result = result.replaceAll(arDigit, enDigit);
      }
    });

    // 6. إزالة علامات الترقيم والأقواس والرموز
    result = result.replaceAll(_punctuationRegex, ' ');

    // 7. تقليص المسافات الزائدة وتحويل الأحرف اللاتينية إلى صغيرة
    result = result.replaceAll(_spacesRegex, ' ').trim().toLowerCase();

    return result;
  }

  /// هل النصين متطابقين بعد التطبيع
  static bool areEqual(String a, String b) {
    return normalize(a) == normalize(b);
  }

  /// هل النص موجود في قائمة نصوص تم تطبيعها (باستخدام Set للبحث السريع)
  static bool contains(Iterable<String> list, String target) {
    final normTarget = normalize(target);
    for (final item in list) {
      if (normalize(item) == normTarget) {
        return true;
      }
    }
    return false;
  }

  /// حساب بصمة تشفيرية موحدة (SHA-256) للنص بعد التطبيع
  static String hashText(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return '';
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// بصمة نص السؤال لتحدي الشلة
  static String triviaQuestionHash(String prompt) {
    return hashText(prompt);
  }

  /// بصمة الإجابة الصحيحة مع القسم لكشف نفس السؤال المصاغ بطرق مختلفة
  static String triviaAnswerHash(String category, String correctAnswer) {
    final normCategory = normalize(category);
    final normAnswer = normalize(correctAnswer);
    if (normAnswer.isEmpty) return '';
    final combined = '$normCategory:$normAnswer';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// بصمة الكلمة (للجاسوس والتمثيل)
  static String wordHash(String word) {
    return hashText(word);
  }

  /// بصمة مملحة للإجابة الصحيحة للتحقق الأوفلاين السري دون كشف رقم الإجابة
  static String saltedAnswerHash(int questionId, String answer, {String salt = 'LammaSecretSalt2025'}) {
    final normAnswer = normalize(answer);
    final combined = '$questionId::$normAnswer::$salt';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // ==========================================
  // فحص التشابه العالي والصياغات المترادفة (Fuzzy Similarity)
  // ==========================================

  // كلمات التوقف الشائعة في العامية والفصحى التي لا تؤثر على جوهر السؤال
  static const Set<String> _stopWords = {
    'في', 'من', 'على', 'عن', 'الى', 'الي', 'هو', 'هي', 'هم', 'هن',
    'ده', 'دي', 'دول', 'مين', 'ايه', 'كام', 'اين', 'متي', 'كيف', 'ما',
    'ماذا', 'هل', 'ان', 'مع', 'كل', 'يا', 'لا', 'لم', 'لن', 'لو', 'او',
    'ثم', 'بين', 'عند', 'كان', 'كانت', 'يكون', 'تكون', 'اللي', 'الذي', 'التي',
  };

  /// استخراج الكلمات الدلالية الأساسية بعد التطبيع وحذف كلمات التوقف
  static Set<String> tokenize(String text) {
    final norm = normalize(text);
    if (norm.isEmpty) return const {};

    final words = norm.split(' ').where((w) => w.length > 1).toList();
    final meaningful = words.where((w) => !_stopWords.contains(w)).toSet();

    // إذا كانت الجملة قصيرة جداً وأصبحت فارغة، نعتمد كل الكلمات المطبّعة
    return meaningful.isNotEmpty ? meaningful : words.toSet();
  }

  /// حساب معامل تشابه جكارد (Jaccard Similarity) بين نصين (0.0 إلى 1.0)
  static double jaccardSimilarity(String a, String b) {
    if (areEqual(a, b)) return 1.0;

    final tokensA = tokenize(a);
    final tokensB = tokenize(b);

    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;

    if (union == 0) return 0.0;
    return intersection / union;
  }

  /// التحقق من التشابه العالي بين نصين مع عتبة قابلة للضبط (افتراضياً 70%)
  static bool isSimilar(String a, String b, {double threshold = 0.70}) {
    if (areEqual(a, b)) return true;
    return jaccardSimilarity(a, b) >= threshold;
  }

  /// التحقق مما إذا كان النص مرادفاً أو مشابهاً بنسبة عالية لأي نص في قائمة سابقة
  static bool hasHighSimilarity(
    Iterable<String> existingTexts,
    String candidate, {
    double threshold = 0.70,
  }) {
    final candidateTokens = tokenize(candidate);
    if (candidateTokens.isEmpty) return false;

    final candidateNorm = normalize(candidate);

    for (final existing in existingTexts) {
      if (normalize(existing) == candidateNorm) return true;

      final existingTokens = tokenize(existing);
      if (existingTokens.isEmpty) continue;

      final intersection = candidateTokens.intersection(existingTokens).length;
      final union = candidateTokens.union(existingTokens).length;

      if (union > 0 && (intersection / union) >= threshold) {
        return true;
      }
    }
    return false;
  }

  /// حساب بصمات قائمة من النصوص دفعة واحدة في isolate منفصل
  static Future<List<String>> computeHashesInBackground(List<String> texts) {
    if (texts.isEmpty) return Future.value([]);
    if (texts.length < 20) {
      return Future.value(texts.map(hashText).toList());
    }
    return compute(_batchHashWorker, texts);
  }

  static List<String> _batchHashWorker(List<String> texts) {
    return texts.map(hashText).toList();
  }
}

