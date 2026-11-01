// Lamma - by Mohamed Ibrahim
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/charades/controllers/charades_controller.dart';
import 'package:lamma_party_game_app/features/charades/controllers/charades_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalStorage storage;
  late ApiClient apiClient;
  late GameContentService contentService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorage(prefs);
    apiClient = ApiClient(storage);
    contentService = GameContentService(apiClient, storage);
  });

  group('Charades Infinite Words & Fallback Tests', () {
    test('1. قسم فاضٍ أو غير موجود لا يؤدي لقائمة فاضية أبداً', () async {
      // فئة غير موجودة إطلاقاً
      final wordsEmptyCat = await contentService.getCharadesWords(
        count: 15,
        category: 'non_existent_category_123',
      );
      expect(wordsEmptyCat, isNotEmpty);
      expect(wordsEmptyCat.length, equals(15));

      // فئة فارغة
      final wordsBlank = await contentService.getCharadesWords(
        count: 10,
        category: '',
      );
      expect(wordsBlank, isNotEmpty);
      expect(wordsBlank.length, equals(10));

      // فئة 'verbs' تُترجم وتُجلب أفعال بدون فشل
      final wordsVerbs = await contentService.getCharadesWords(
        count: 10,
        category: 'verbs',
      );
      expect(wordsVerbs, isNotEmpty);
      expect(wordsVerbs.length, equals(10));

      // قسم 'jobs'
      final wordsJobs = await contentService.getCharadesWords(
        count: 10,
        category: 'jobs',
      );
      expect(wordsJobs, isNotEmpty);
      expect(wordsJobs.length, equals(10));
    });

    test('2. عدم ظهور رسالة النفاد وتدوير الكلمات حتى بعد استهلاك القائمة عدة مرات', () async {
      // نحاكي استهلاك كل الكلمات المحلية في البنك بتعليمها كمشاهدة في Storage
      final allWords = {
        ...kFallbackCharadesMovies,
        ...kFallbackCharadesJobs,
        ...kFallbackCharadesActions,
        ...kFallbackCharadesMixed,
      }.toList();
      await storage.markCharadesWordsSeen(allWords);
      expect(storage.getSeenCharadesWords().length, equals(allWords.length));

      // نطلب كلمات جديدة من فئة معينة بعد استنزاف جميع كلماتها
      final recycledWords = await contentService.getCharadesWords(
        count: 20,
        category: 'movies',
      );

      // يجب أن لا ترجع فارغة إطلاقاً بل تُعيد التدوير بتفضيل الأقدم مشاهدة
      expect(recycledWords, isNotEmpty);
      expect(recycledWords.length, equals(20));

      // التأكد أن الكلمات لا تحتوي على مصفوفة فارغة
      final seenSet = recycledWords.toSet();
      expect(seenSet.length, equals(20)); // بدون تكرار في نفس الدفعة
    });

    test('3. حذف نص "خلصت الكلمات!" نهائياً من كلاس الحالة', () {
      // فحص الحالة عندما تكون مصفوفة الكلمات فارغة
      const emptyState = CharadesGameState(
        words: [],
        currentWordIndex: 0,
      );
      expect(emptyState.currentWord, isNot(contains('خلصت الكلمات')));
      expect(emptyState.currentWord, isEmpty);

      // فحص الحالة عندما يتجاوز الفهرس طول المصفوفة
      const overrunState = CharadesGameState(
        words: ['الناظر', 'الكيف'],
        currentWordIndex: 5,
      );
      expect(overrunState.currentWord, isNot(contains('خلصت الكلمات')));
      expect(overrunState.currentWord, equals('الكيف'));
    });

    test('4. إعدادات قديمة تالفة لا تكسر اللعبة وتُصلح تلقائياً', () async {
      // حفظ إعداد تالف أو قديم بالقيم القديمة ('verbs')
      await prefs.setString('lamma_charades_category', 'verbs');
      await prefs.setInt('lamma_charades_round_seconds', 45);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final settings = container.read(charadesSettingsProvider);
      // يجب أن يتم تصحيحها تلقائياً إلى 'actions'
      expect(settings.category, equals('actions'));
      expect(settings.roundSeconds, equals(45));

      // والتأكد أن اللعبة تبدأ بدون أخطاء
      final gameNotifier = container.read(charadesGameProvider.notifier);
      await gameNotifier.initGame();

      final gameState = container.read(charadesGameProvider);
      expect(gameState.words, isNotEmpty);
      expect(gameState.currentWord, isNotEmpty);
      expect(gameState.currentWord, isNot(contains('خلصت الكلمات')));
    });

    test('5. تحميل متأخر: لا تبدأ الجولة بالتايمر قبل جاهزية الكلمات', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final initialGameState = container.read(charadesGameProvider);
      // الحالة المبدئية قبل initGame
      expect(initialGameState.hasWords, isFalse);

      final notifier = container.read(charadesGameProvider.notifier);
      await notifier.initGame();

      final readyState = container.read(charadesGameProvider);
      expect(readyState.hasWords, isTrue);
      expect(readyState.isLoading, isFalse);
      expect(readyState.words.length, greaterThanOrEqualTo(25));
    });
  });
}
