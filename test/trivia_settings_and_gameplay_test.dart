// Lamma - by Mohamed Ibrahim
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock ApiClient للتحكم في استجابات الـ AI والـ API في الاختبارات
class MockApiClient extends ApiClient {
  List<Map<String, dynamic>> mockAiContent = [];
  QuestionsResponse? mockQuestionsResponse;
  bool throwOnAi = false;

  MockApiClient(super.storage);

  @override
  Future<QuestionsResponse?> fetchQuestions({
    String? categories,
    String? difficulty,
    int count = 10,
  }) async {
    return mockQuestionsResponse;
  }

  @override
  Future<List<Map<String, dynamic>>> generateAiContent({
    required String gameType,
    String? category,
    List<String>? categories,
    String? difficulty,
    int count = 20,
    List<String> excludeItems = const [],
  }) async {
    if (throwOnAi) {
      throw Exception('AI generation failed');
    }
    return mockAiContent;
  }

  @override
  Future<bool> markQuestionsSeen(List<int> questionIds) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage storage;
  late MockApiClient mockApi;
  late GameContentService contentService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorage(prefs);
    mockApi = MockApiClient(storage);
    contentService = GameContentService(mockApi, storage);
  });

  group('اختبارات إعدادات تحدي الشلة ومنطق توليد الأسئلة', () {
    // 1) عدد الأسئلة يطابق المختار بالضبط
    test('1. عدد الأسئلة يطابق المختار بالضبط ولا يُعرض سؤال زائد', () async {
      const selectedCount = 5;

      final questions = await contentService.getTriviaQuestions(
        count: selectedCount,
        categories: ['movies', 'sports'],
        allowAi: false,
      );

      expect(questions.length, equals(selectedCount));

      final notifier = TriviaGameNotifier(
        initialQuestions: questions,
        totalSeconds: 15,
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      expect(notifier.state.totalQuestions, equals(selectedCount));
      expect(notifier.state.currentQuestionIndex, equals(0));

      // محاكاة الإجابة على كل الأسئلة
      for (int i = 0; i < selectedCount; i++) {
        expect(notifier.state.currentQuestionIndex, equals(i));
        notifier.submitAnswer(0);
        notifier.advanceFromReveal();
        notifier.advanceFromLeaderboard();
      }

      // بعد السؤال الخامس تنتهي اللعبة ولا يوجد أي سؤال إضافي
      expect(notifier.state.phase, equals(TriviaPhase.completed));
    });

    // 2) وقت السؤال المختار يصل للمؤقت ويبدأ منه العداد
    test('2. الوقت المختار يصل للمؤقت ويعاد ضبطه عند كل سؤال جديد', () async {
      const selectedTime = 20;

      final notifier = TriviaGameNotifier(
        initialQuestions: [
          kFallbackTriviaQuestions[0],
          kFallbackTriviaQuestions[1],
        ],
        totalSeconds: selectedTime,
        startWithSelection: false,
      );
      addTearDown(notifier.dispose);

      // العداد يبدأ من 20 ثانية بالضبط
      expect(notifier.state.totalSeconds, equals(selectedTime));
      expect(notifier.state.secondsLeft, equals(selectedTime));

      // إجابة السؤال الأول والانتقال للثاني
      notifier.submitAnswer(0);
      notifier.advanceFromReveal();
      notifier.advanceFromLeaderboard();

      // السؤال الثاني يبدأ بنفس الوقت المختار (20 ثانية)
      expect(notifier.state.currentQuestionIndex, equals(1));
      expect(notifier.state.secondsLeft, equals(selectedTime));
    });

    // 3) قسم واحد مختار: كل الأسئلة تأتي من هذا القسم فقط
    test('3. قسم واحد مختار: كل الأسئلة من هذا القسم فقط ولا يخرج عنه إطلاقاً', () async {
      final questions = await contentService.getTriviaQuestions(
        count: 5,
        categories: ['movies'],
        allowAi: false,
      );

      expect(questions.length, equals(5));
      for (final q in questions) {
        expect(q.categorySlug, equals('movies'),
            reason: 'السؤال ${q.promptAr} ليس من قسم الأفلام!');
      }
    });

    // 4) عدة أقسام مختارة: لا تتجاوز الأقسام المختارة
    test('4. عدة أقسام مختارة: الأسئلة تأتي من الأقسام المختارة فقط', () async {
      final chosenCategories = ['movies', 'sports'];

      final questions = await contentService.getTriviaQuestions(
        count: 8,
        categories: chosenCategories,
        allowAi: false,
      );

      expect(questions.length, equals(8));
      for (final q in questions) {
        expect(chosenCategories.contains(q.categorySlug), isTrue,
            reason: 'السؤال ${q.promptAr} من قسم غير مصرح: ${q.categorySlug}');
      }

      // التأكد أن هناك تمثيلاً للأقسام المختارة
      final foundCategories = questions.map((q) => q.categorySlug).toSet();
      expect(foundCategories.length, greaterThanOrEqualTo(2));
    });

    // 5) خيار "الكل" ينتج تنوعاً بين مختلف الأقسام
    test('5. خيار "الكل" ينتج تنوعاً متوازناً بدون هيمنة قسم واحد', () async {
      final questions = await contentService.getTriviaQuestions(
        count: 10,
        categories: ['movies', 'sports', 'afeehat', 'history', 'general'],
        allowAi: false,
      );

      expect(questions.length, equals(10));
      final categoriesPresent = questions.map((q) => q.categorySlug).toSet();
      // خيار الكل يجب أن يشمل على الأقل 3 أقسام مختلفة في 10 أسئلة
      expect(categoriesPresent.length, greaterThanOrEqualTo(3));
    });

    // 6) رفض الأسئلة المخالفة من ناتج الـ AI والتحقق الصارم
    test('6. رفض الأسئلة المخالفة من ناتج الـ AI (3 اختيارات، خيارات مكررة، صعوبة مخالفة، إلخ)', () async {
      mockApi.mockAiContent = [
        // سؤال غير صالح: 3 اختيارات فقط (يجب رفضه)
        {
          'prompt_ar': 'سؤال به 3 اختيارات فقط',
          'options': ['أ', 'ب', 'ج'],
          'correct_index': 0,
          'category_slug': 'movies',
          'difficulty': 'easy',
        },
        // سؤال غير صالح: اختيارات مكررة (يجب رفضه)
        {
          'prompt_ar': 'سؤال به اختيارات مكررة',
          'options': ['الأهلي', 'الزمالك', 'الأهلي', 'الإسماعيلي'],
          'correct_index': 1,
          'category_slug': 'movies',
          'difficulty': 'easy',
        },
        // سؤال غير صالح: correct_index خارج النطاق 0..3 (يجب رفضه)
        {
          'prompt_ar': 'سؤال بمؤشر إجابة خاطئ',
          'options': ['1', '2', '3', '4'],
          'correct_index': 5,
          'category_slug': 'movies',
          'difficulty': 'easy',
        },
        // سؤال غير صالح: قسم خارج القسم المختار (يجب رفضه)
        {
          'prompt_ar': 'سؤال في قسم الكورة والمطلوب أفلام',
          'options': ['أ', 'ب', 'ج', 'د'],
          'correct_index': 0,
          'category_slug': 'sports',
          'difficulty': 'easy',
        },
        // سؤال صالح 100% (يجب قبوله)
        {
          'prompt_ar': 'مين مخرج فيلم باب الحديد؟',
          'options': ['يوسف شاهين', 'صلاح أبو سيف', 'عاطف الطيب', 'هنري بركات'],
          'correct_index': 0,
          'category_slug': 'movies',
          'difficulty': 'easy',
        },
      ];

      final questions = await contentService.getTriviaQuestions(
        count: 1,
        categories: ['movies'],
        difficulty: 'easy',
        allowAi: true,
      );

      expect(questions.length, equals(1));
      expect(questions.first.promptAr, equals('مين مخرج فيلم باب الحديد؟'));
      expect(questions.first.options.length, equals(4));
      expect(questions.first.correctIndex, equals(0));
      expect(questions.first.categorySlug, equals('movies'));
    });

    // 7) سلوك عدم كفاية الأسئلة: رمي استثناء مخصص وعدم الإكمال من أقسام أخرى بصمت
    test('7. سلوك عدم كفاية الأسئلة: رمي InsufficientTriviaQuestionsException وعدم الخلط', () async {
      // في البنك المحلي قسم التاريخ يحتوي على عدد محدود جداً من الأسئلة الصعبة
      // إذا طلبنا 10 أسئلة بصعوبة 'hard' لقسم 'history' وبدون AI
      expect(
        () async => await contentService.getTriviaQuestions(
          count: 10,
          categories: ['history'],
          difficulty: 'hard',
          allowAi: false,
        ),
        throwsA(isA<InsufficientTriviaQuestionsException>()),
      );
    });

    // 8) الحفظ والاسترجاع بعد إعادة تشغيل التطبيق
    test('8. حفظ الإعدادات محلياً واسترجاعها بنجاح بعد إعادة التشغيل', () async {
      // تعديل الإعدادات وحفظها
      final notifier = TriviaSettingsNotifier(storage);
      await notifier.update(
        questionsCount: 15,
        timePerQuestion: 25,
        difficulty: 'hard',
        categories: ['movies', 'afeehat'],
      );

      expect(storage.hasTriviaSettings(), isTrue);

      // محاكاة إغلاق التطبيق وفتحه من جديد بـ LocalStorage و Notifier جديد
      final freshNotifier = TriviaSettingsNotifier(storage);
      final loadedSettings = freshNotifier.state;

      expect(loadedSettings.questionsCount, equals(15));
      expect(loadedSettings.timePerQuestion, equals(25));
      expect(loadedSettings.difficulty, equals('hard'));
      expect(loadedSettings.categories, equals(['movies', 'afeehat']));
    });

    // 9) استخدام القيمة الافتراضية فقط عند أول تشغيل وعدم وجود قيم محفوظة
    test('9. القيمة الافتراضية تُستخدم فقط عند عدم وجود قيمة محفوظة', () async {
      // ذاكرة فارغة (أول تشغيل)
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshStorage = LocalStorage(freshPrefs);

      expect(freshStorage.hasTriviaSettings(), isFalse);

      final notifier = TriviaSettingsNotifier(freshStorage);
      final initialSettings = notifier.state;

      // التأكد من استخدام القيم الافتراضية
      expect(initialSettings.questionsCount, equals(10));
      expect(initialSettings.timePerQuestion, equals(15));
      expect(initialSettings.difficulty, equals('all'));
      expect(initialSettings.categories.length, equals(5));
    });
  });
}
