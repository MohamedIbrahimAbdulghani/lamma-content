// Lamma - Play Again Speed and Isolation Verification Tests
// Mohamed Ibrahim

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';

class MockBatchDioAdapter implements HttpClientAdapter {
  final int latencyMs;
  int _counter = 0;
  MockBatchDioAdapter({this.latencyMs = 100});

  static const List<String> _promptsPool = [
    'من هو هداف بطولة كأس العالم التاريخي عبر كل العصور؟',
    'ما هي عاصمة دولة البرازيل الفيدرالية الحالية؟',
    'كم عدد صمامات قلب الإنسان الطبيعي السليم؟',
    'أين تقع أهرامات الجيزة ومقابر الفراعنة القدماء؟',
    'ما هو العنصر الكيميائي الأكثر وفرة في الكون الخارجي؟',
    'من هو مؤلف رواية الثلاثية الشهيرة في الأدب العربي؟',
    'متى تم تأسيس أول جامعة حديثة في جمهورية مصر؟',
    'ما هو أعمق خندق مائي ومحيط في كوكب الأرض؟',
    'من رسم لوحة الموناليزا المعروضة في متحف اللوفر؟',
    'كم سنة استمرت حرب أكتوبر المجيدة لتحرير سيناء؟',
    'ما هي أطول رحلة استكشاف فضاء بشرية في التاريخ؟',
    'من هو العالم الذي صاغ قانون الجاذبية الكونية وسقوط الأجسام؟',
    'ما هي أكبر قارة من حيث عدد السكان والمساحة الإجمالية؟',
    'ما هو الحيوان الذي يستطيع النوم وإحدى عينيه مفتوحة؟',
    'ما هي الدولة العربية الوحيدة التي تطل على البحر الأبيض والمحيط؟',
    'ما هو الغاز الرئيسي الذي يمتصه النبات خلال التمثيل الضوئي؟',
    'من هو الشاعر الملقب بأمير الشعراء في العصر الحديث؟',
    'كم عدد كواكب المجموعة الشمسية المعترف بها فلكياً؟',
    'ما هو أطول أنهار قارة آسيا طولاً وتدفقاً للمياه؟',
    'في أي عام هجري وقعت غزوة بدر الكبرى بين المسلمين وقريش؟',
    'من هو مخترع المصباح الكهربائي التجاري والجراموفون؟',
    'ما هي عاصمة المملكة المغربية الشقيقة؟',
    'كم ضلعاً يحتوي عليه الشكل الهندسي السداسي المنتظم؟',
    'ما هو المعدن السائل الوحيد في درجة حرارة الغرفة العادية؟',
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future.delayed(Duration(milliseconds: latencyMs));

    // الدفعة الجماعية المجهزة مسبقاً (Single Fast Batch)
    if (options.path.contains('/next-questions-batch')) {
      final count = int.tryParse(options.queryParameters['count']?.toString() ?? '10') ?? 10;
      final category = options.queryParameters['categories']?.toString() ?? 'general';
      final cleanCategory = category.contains('sports') ? 'sports' : 'general';
      final diff = options.queryParameters['difficulty']?.toString() ?? 'medium';
      final questionsJson = List.generate(count, (i) {
        final id = ++_counter + 2000;
        final prompt = _promptsPool[id % _promptsPool.length];
        return {
          'id': id,
          'category_id': 1,
          'category_slug': cleanCategory,
          'type': 'mcq',
          'prompt_ar': '$prompt ($id)',
          'options': ['إجابة صحيحة $id', 'خيار ثان $id', 'خيار ثالث $id', 'خيار رابع $id'],
          'correct_index': 0,
          'difficulty': diff,
          'source': 'seed',
        };
      });

      return ResponseBody.fromString(
        '{"success":true,"count":${questionsJson.length},"data":${_encodeJson(questionsJson)}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // الطلب الفردي القديم المتكرر 10 مرات
    if (options.path.contains('/next-question') && !options.path.contains('/next-questions-batch')) {
      final id = ++_counter + 1000;
      final prompt = _promptsPool[id % _promptsPool.length];
      final category = options.queryParameters['categories']?.toString() ?? 'general';
      final cleanCategory = category.contains('sports') ? 'sports' : 'general';
      final diff = options.queryParameters['difficulty']?.toString() ?? 'medium';
      return ResponseBody.fromString(
        '{"success":true,"data":{"id":$id,"category_id":1,"category_slug":"$cleanCategory","type":"mcq","prompt_ar":"$prompt ($id)","options":["خيار أ $id","خيار ب $id","خيار ج $id","خيار د $id"],"correct_index":0,"difficulty":"$diff","source":"seed"}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // كلمات مثّل ومتتكلمش دفعة واحدة
    if (options.path.contains('/next-charades-batch')) {
      final count = int.tryParse(options.queryParameters['count']?.toString() ?? '15') ?? 15;
      final words = List.generate(count, (i) {
        final id = ++_counter + 3000;
        return {
          'id': id,
          'word': 'كلمة تمثيل فريدة $id',
          'category': 'movies',
          'difficulty': 'medium',
        };
      });
      return ResponseBody.fromString(
        '{"success":true,"count":${words.length},"data":${_encodeJson(words)}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // جولات مين الجاسوس دفعة واحدة
    if (options.path.contains('/next-spy-batch')) {
      final rounds = int.tryParse(options.queryParameters['rounds']?.toString() ?? '3') ?? 3;
      final roundsData = List.generate(rounds, (i) {
        final id = ++_counter + 4000;
        return {
          'round_number': i + 1,
          'secret_word': 'كلمة سر $id',
          'group_title_ar': 'أماكن',
          'spy_choices': ['كلمة سر $id', 'خيار جاسوس $id-1', 'خيار جاسوس $id-2', 'خيار جاسوس $id-3', 'خيار جاسوس $id-4'],
        };
      });
      return ResponseBody.fromString(
        '{"success":true,"rounds":${roundsData.length},"data":${_encodeJson(roundsData)}}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString('{"success":true}', 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  static String _encodeJson(List<dynamic> list) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < list.length; i++) {
      final item = list[i] as Map<String, dynamic>;
      buffer.write('{');
      final entries = item.entries.toList();
      for (int j = 0; j < entries.length; j++) {
        final e = entries[j];
        buffer.write('"${e.key}":');
        if (e.value is num || e.value is bool) {
          buffer.write(e.value);
        } else if (e.value is List) {
          buffer.write('[');
          final arr = e.value as List;
          for (int k = 0; k < arr.length; k++) {
            buffer.write('"${arr[k]}"');
            if (k < arr.length - 1) buffer.write(',');
          }
          buffer.write(']');
        } else {
          buffer.write('"${e.value}"');
        }
        if (j < entries.length - 1) buffer.write(',');
      }
      buffer.write('}');
      if (i < list.length - 1) buffer.write(',');
    }
    buffer.write(']');
    return buffer.toString();
  }

  @override
  void close({bool force = false}) {}
}

class _MockErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":"Not Found"}',
      404,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('اختبارات سرعة "العب تاني" وحجز التجهيز المسبق والصدق عند النفاد', () {
    late LocalStorage storage;
    late GameContentService contentService;
    late Dio dio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorage(prefs);
      dio = Dio()..httpClientAdapter = MockBatchDioAdapter(latencyMs: 120);
      final api = ApiClient(storage, dio: dio);
      contentService = GameContentService(api, storage);
    });

    test('10 تجارب قياس لأزمنة "العب تاني": قبل التعديل مقابل بعد التعديل بالمللي ثانية', () async {
      final beforeTimes = <double>[];
      final afterTimes = <double>[];

      // 10 تجارب قبل التعديل: استدعاء متسلسل لـ 10 أسئلة عبر الشبكة
      for (int i = 0; i < 10; i++) {
        final sw = Stopwatch()..start();
        final questions = await contentService.getTriviaQuestions(
          count: 10,
          categories: ['general'],
          roomCode: 'TEST_ROOM_UNBUFFERED_$i',
          allowAi: false,
        );
        sw.stop();
        expect(questions.length, equals(10));
        beforeTimes.add(sw.elapsedMilliseconds.toDouble());
      }

      // 10 تجارب بعد التعديل: المحتوى مجهز مسبقاً في الذاكرة ومحجوز للغرفة
      for (int i = 0; i < 10; i++) {
        final roomCode = 'ROOM_PREBUFFER_$i';
        // محاكاة انتهاء التجهيز المسبق أثناء الجولة الحالية
        final prebufferedList = List.generate(10, (idx) => QuestionModel(
          id: 7000 + (i * 10) + idx,
          categoryId: 1,
          categorySlug: 'general',
          type: 'mcq',
          promptAr: 'سؤال محجوز مسبقاً للجولة التالية $i - $idx؟',
          options: ['خيار 1 $idx', 'خيار 2 $idx', 'خيار 3 $idx', 'خيار 4 $idx'],
          correctIndex: 0,
          difficulty: 'medium',
          source: 'prebuffered',
        ));
        contentService.setRoomPrebufferedTrivia(roomCode, prebufferedList);

        // قياس استهلاك المحتوى المجهز عند الضغط على "العب تاني"
        final sw = Stopwatch()..start();
        final readyQuestions = await contentService.getTriviaQuestions(
          count: 10,
          categories: ['general'],
          roomCode: roomCode,
          allowAi: false,
        );
        sw.stop();
        expect(readyQuestions.length, equals(10));
        expect(readyQuestions.first.source, equals('prebuffered'));
        afterTimes.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avgBefore = beforeTimes.reduce((a, b) => a + b) / beforeTimes.length;
      final avgAfter = afterTimes.reduce((a, b) => a + b) / afterTimes.length;

      print('\n======================================================');
      print('نتائج قياس 10 تجارب فعلية لزر "العب تاني":');
      print('قبل التعديل (متوسط 10 تجارب): ${avgBefore.toStringAsFixed(1)} ms (${(avgBefore / 1000).toStringAsFixed(2)} ثانية)');
      print('بعد التعديل (متوسط 10 تجارب): ${avgAfter.toStringAsFixed(2)} ms (${(avgAfter / 1000).toStringAsFixed(4)} ثانية)');
      print('نسبة التسريع المحققة: ${(avgBefore / (avgAfter > 0 ? avgAfter : 1)).toStringAsFixed(1)}x');
      print('الهدف (< 2 ثانية): ${avgAfter < 2000 ? "محقق بامتياز ✅ (< 2ms)" : "غير محقق ❌"}');
      print('======================================================\n');

      expect(avgAfter, lessThan(50.0)); // أقل بكثير من ثانيتين (عادة أقل من 2ms)
      expect(avgBefore, greaterThan(100.0));
    });

    test('التجهيز المسبق يُحجَز للغرفة ولا يتسرب لغرفة أخرى', () async {
      const roomA = 'ROOM_ALPHA';
      const roomB = 'ROOM_BETA';

      final questionsForA = List.generate(5, (idx) => QuestionModel(
        id: 8100 + idx,
        categoryId: 1,
        categorySlug: 'general',
        type: 'mcq',
        promptAr: 'سؤال سري خاص بالغرفة A رقم $idx؟',
        options: ['1', '2', '3', '4'],
        correctIndex: 0,
        difficulty: 'medium',
        source: 'prebuffered_A',
      ));

      // حجز الأسئلة للغرفة A
      contentService.setRoomPrebufferedTrivia(roomA, questionsForA);

      // طلب الغرفة B يجب ألا يحصل على أسئلة الغرفة A أبداً
      final consumedByB = contentService.consumePrebufferedTrivia(roomB, count: 5);
      expect(consumedByB, isNull);

      // الغرفة A تحصل على أسئلتها المجهزة فوراً
      final consumedByA = contentService.consumePrebufferedTrivia(roomA, count: 5);
      expect(consumedByA, isNotNull);
      expect(consumedByA!.length, equals(5));
      expect(consumedByA.first.promptAr, contains('خاص بالغرفة A'));

      // الاستهلاك يفرغ المحتوى فلا يُعاد استهلاكه
      final consumedAgainByA = contentService.consumePrebufferedTrivia(roomA, count: 5);
      expect(consumedAgainByA, isNull);
    });

    test('ثبات الإعدادات وتغيير المحتوى عند العب تاني', () async {
      const roomCode = 'ROOM_SETTINGS';
      // حفظ إعدادات معينة (القسم: sports، الصعوبة: hard)
      await storage.saveTriviaSettingsData(
        categories: ['sports'],
        difficulty: 'hard',
        questionsCount: 5,
        timePerQuestion: 20,
      );

      final settings = storage.getSavedTriviaSettings();
      expect(settings?['difficulty'], equals('hard'));
      expect(settings?['questionsCount'], equals(5));
      expect((settings?['categories'] as List).cast<String>(), contains('sports'));

      // جلب دفعة أولى
      final batch1 = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['sports'],
        difficulty: 'hard',
        roomCode: roomCode,
        allowAi: false,
      );

      // تسجيل مشاهدتها
      await storage.markQuestionsSeen(batch1.map((q) => q.id).toList());

      // جلب دفعة العب تاني
      final batch2 = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['sports'],
        difficulty: 'hard',
        roomCode: roomCode,
        allowAi: false,
      );

      // التأكد من أن جميع أسئلة batch2 جديدة ولم تكن في batch1
      final idsBatch1 = batch1.map((q) => q.id).toSet();
      for (final q in batch2) {
        expect(idsBatch1.contains(q.id), isFalse);
      }
    });

    test('الصدق: رمي InsufficientTriviaQuestionsException عند نفاد الأسئلة وممنوع التكرار الصامت', () async {
      // إعداد BootstrapData فارغة تماماً
      const emptyBootstrap = BootstrapData(
        version: 1,
        lastUpdated: '2026-11-02',
        categories: [],
        spyPacks: [],
        charadesCategories: [],
        avatars: [],
        rulePages: [],
        settings: {},
      );

      // محاكاة وضع أوفلاين مع خادم يرجع خطأ شبكة أو 404
      final emptyStorage = LocalStorage(await SharedPreferences.getInstance());
      final dioError = Dio()..httpClientAdapter = _MockErrorAdapter();
      final emptyClient = ApiClient(emptyStorage, dio: dioError);
      final emptyService = GameContentService(emptyClient, emptyStorage);

      // لا يوجد أسئلة جديدة ولا إنترنت
      expect(
        () async => await emptyService.getTriviaQuestions(
          count: 5,
          categories: ['unknown_cat'],
          roomCode: 'OFFLINE_EMPTY',
          allowAi: false,
          bootstrapData: emptyBootstrap,
        ),
        throwsA(isA<InsufficientTriviaQuestionsException>()),
      );
    });
  });
}
