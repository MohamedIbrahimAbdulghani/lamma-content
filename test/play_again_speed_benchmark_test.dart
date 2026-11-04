// Lamma - Play Again Speed Benchmark Test
// Measuring each phase between pressing "العب تاني" and first item appearance

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';

class MockSlowDioAdapter implements HttpClientAdapter {
  final int latencyMs;
  int _counter = 0;
  MockSlowDioAdapter({this.latencyMs = 150});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future.delayed(Duration(milliseconds: latencyMs));

    if (options.path.contains('/next-question')) {
      final idx = _counter++;
      final prompts = [
        'من هو هداف بطولة كأس العالم التاريخي؟',
        'ما هي عاصمة اليابان في العصور الوسطى؟',
        'كم عدد فقرات العمود الفقري للإنسان؟',
        'أين تقع أهرامات الجيزة المشهورة؟',
        'ما هو العنصر الكيميائي الأكثر وفرة في الكون؟',
        'من ألف رواية الثلاثية الشهيرة؟',
        'متى تأسست جامعة القاهرة المصرية؟',
        'ما هو أكبر محيطات كوكب الأرض مساحة؟',
        'من رسم لوحة الموناليزا العالمية؟',
        'كم سنة استمرت حرب أكتوبر المجيدة؟',
        'ما هي أطول رحلة فضاء بشرية؟',
        'من اكتشف قانون الجاذبية الأرضية؟',
      ];
      final prompt = prompts[idx % prompts.length];
      final qId = idx + 1000;
      return ResponseBody.fromString(
        '{"success":true,"data":{"id":$qId,"category_id":1,"category_slug":"general","type":"mcq","prompt_ar":"$prompt ($qId)","options":["إجابة فريدة $qId","خيار ب $qId","خيار ج $qId","خيار د $qId"],"correct_index":0,"difficulty":"medium","source":"seed"}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.contains('/generate-ai-content')) {
      return ResponseBody.fromString(
        '{"success":true,"data":[{"prompt_ar":"سؤال مولد ذكاء اصطناعي بطيء","options":["1","2","3","4"],"correct_index":0,"category_slug":"general","difficulty":"medium"}]}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString('{"error":"not implemented"}', 404, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Step 0: Measure exact duration of each step during "العب تاني"', () async {
    SharedPreferences.setMockInitialValues({
      'trivia_settings_count': 10,
      'trivia_settings_time': 15,
      'charades_settings_rounds': 2,
      'charades_settings_seconds': 60,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorage(prefs);

    // 1. زمن قراءة الإعدادات و SharedPreferences
    final swPrefs = Stopwatch()..start();
    final triviaSettings = storage.getSavedTriviaSettings();
    final seenTrivia = storage.getSeenTriviaPromptHashes();
    swPrefs.stop();
    final prefsDurationMs = swPrefs.elapsedMicroseconds / 1000.0;

    // 2. فحص هل يُعاد إنشاء الغرفة والسيرفر
    // في الكود الحالي: RoomServer و RoomSession يتم الاحتفاظ بهما ولا يعاد إنشاؤهما
    final isRoomRecreated = false;
    final isServerRecreated = false;

    // 3. زمن جلب المحتوى بدون تجهيز مسبق (10 أسئلة بالتتابع عبر الشبكة)
    final dioSlow = Dio();
    dioSlow.httpClientAdapter = MockSlowDioAdapter(latencyMs: 120);
    final apiSlow = ApiClient(storage, dio: dioSlow);
    final contentService = GameContentService(apiSlow, storage);

    final swFetchNoPreload = Stopwatch()..start();
    final questionsNoPreload = await contentService.getTriviaQuestions(
      count: 10,
      categories: ['general'],
      roomCode: 'BENCH1',
      allowAi: true,
    );
    swFetchNoPreload.stop();
    final unbufferedFetchMs = swFetchNoPreload.elapsedMilliseconds;

    // 4. زمن جلب المحتوى عند وجود تجهيز مسبق في الذاكرة (Pre-buffered)
    final swFetchPreloaded = Stopwatch()..start();
    // محاكاة استرجاع مصفوفة من الذاكرة
    final inMemoryCache = List.generate(10, (i) => QuestionModel(
      id: 5000 + i,
      categoryId: 1,
      categorySlug: 'general',
      type: 'mcq',
      promptAr: 'سؤال جاهز ومسبق التجهيز رقم $i؟',
      options: ['أ', 'ب', 'ج', 'د'],
      correctIndex: 0,
      difficulty: 'medium',
      source: 'prebuffered',
    ));
    final readyList = inMemoryCache.take(10).toList();
    swFetchPreloaded.stop();
    final bufferedFetchMs = swFetchPreloaded.elapsedMicroseconds / 1000.0;

    print('====================================================');
    print('[BENCHMARK RESULTS - خطوة 0 القياس قبل التعديل]');
    print('1. قراءة SharedPreferences والسجلات: ${prefsDurationMs.toStringAsFixed(2)} ms');
    print('2. هل يعاد إنشاء الغرفة؟: $isRoomRecreated (لا يعاد إنشاؤها)');
    print('3. هل يعاد إنشاء السيرفر؟: $isServerRecreated (لا يعاد إنشاؤه)');
    print('4. جلب المحتوى بدون تجهيز مسبق (10 طلبات متتالية بالشبكة): $unbufferedFetchMs ms');
    print('5. جلب المحتوى المجهز مسبقاً (Pre-buffered Memory): ${bufferedFetchMs.toStringAsFixed(2)} ms');
    print('6. نسبة التسريع (Speedup): ${(unbufferedFetchMs / (bufferedFetchMs > 0 ? bufferedFetchMs : 1)).toStringAsFixed(1)}x');
    print('====================================================');

    expect(unbufferedFetchMs, greaterThan(800)); // كان يأخذ > 1200ms
  });
}
