// Lamma - by Mohamed Ibrahim
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/constants/charades_words_bank.dart';
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

  group('Charades Words Per Turn & Actable Words Tests', () {
    test(
      '1. إعداد حفظ عدد الكلمات في LocalStorage واستعادته بشكل دائم',
      () async {
        // قبل الحفظ
        expect(storage.hasCharadesSettings(), isFalse);

        // حفظ قيمة جديدة (مثلاً 15 كلمة)
        await storage.saveCharadesSettingsData(
          roundSeconds: 90,
          roundsPerPlayer: 3,
          category: 'movies',
          wordsPerTurn: 15,
        );

        expect(storage.hasCharadesSettings(), isTrue);
        final reloaded = storage.getSavedCharadesSettings();
        expect(reloaded, isNotNull);
        expect(reloaded!['wordsPerTurn'], equals(15));
        expect(reloaded['roundSeconds'], equals(90));
        expect(reloaded['category'], equals('movies'));

        // حفظ خيار "مفتوح" (0)
        await storage.saveCharadesSettingsData(
          roundSeconds: 60,
          roundsPerPlayer: 2,
          category: 'mixed',
          wordsPerTurn: 0,
        );

        final openSettings = storage.getSavedCharadesSettings();
        expect(openSettings, isNotNull);
        expect(openSettings!['wordsPerTurn'], equals(0));
      },
    );

    test(
      '2. انتهاء دور اللاعب فور الوصول للحد المختار (عرفوها + تخطي = الحد)',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localStorageProvider.overrideWithValue(storage),
            gameContentServiceProvider.overrideWithValue(contentService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(charadesGameProvider.notifier);
        final testPlayers = [
          const PlayerModel(id: 'p1', name: 'أحمد', isHost: true),
          const PlayerModel(id: 'p2', name: 'سارة', isHost: false),
        ];

        // تهيئة اللعبة بحد 5 كلمات فقط لكل دور
        await notifier.initGame(
          initialPlayers: testPlayers,
          roundsPerPlayer: 2,
          roundSeconds: 60,
          category: 'mixed',
          wordsPerTurn: 5,
        );

        notifier.startRound();
        var state = container.read(charadesGameProvider);
        expect(state.isRoundActive, isTrue);
        expect(state.wordsPerTurn, equals(5));
        expect(state.isWordsLimitEnabled, isTrue);
        expect(state.currentWordNumberInTurn, equals(1));

        // كلمة 1: صح
        notifier.markCorrect();
        state = container.read(charadesGameProvider);
        expect(state.isRoundActive, isTrue);
        expect(state.correctCountInRound, equals(1));
        expect(state.wordsAttemptedInRound, equals(1));
        expect(state.currentWordNumberInTurn, equals(2));

        // كلمة 2: تخطي
        notifier.markPass();
        state = container.read(charadesGameProvider);
        expect(state.isRoundActive, isTrue);
        expect(state.passedCountInRound, equals(1));
        expect(state.wordsAttemptedInRound, equals(2));
        expect(state.currentWordNumberInTurn, equals(3));

        // كلمة 3: صح
        notifier.markCorrect();
        // كلمة 4: تخطي
        notifier.markPass();

        state = container.read(charadesGameProvider);
        expect(state.isRoundActive, isTrue);
        expect(state.wordsAttemptedInRound, equals(4));
        expect(state.currentWordNumberInTurn, equals(5));

        // كلمة 5: صح (كده وصلنا للحد 5 كلمات: 3 صح + 2 تخطي)
        notifier.markCorrect();

        state = container.read(charadesGameProvider);
        // الدور ينتهي فوراً ويتحول isRoundActive إلى false
        expect(state.isRoundActive, isFalse);
        expect(state.wordsAttemptedInRound, equals(5));
        expect(state.correctCountInRound, equals(3));
        expect(state.passedCountInRound, equals(2));
        expect(state.isWordsLimitReached, isTrue);
      },
    );

    test(
      '3. خيار "مفتوح (بلا حد = 0)" لا يُنهي الدور بتخطي أو إجابة أي عدد من الكلمات',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localStorageProvider.overrideWithValue(storage),
            gameContentServiceProvider.overrideWithValue(contentService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(charadesGameProvider.notifier);
        final testPlayers = [
          const PlayerModel(id: 'p1', name: 'أحمد', isHost: true),
        ];

        // مفتوح (wordsPerTurn = 0)
        await notifier.initGame(
          initialPlayers: testPlayers,
          roundsPerPlayer: 1,
          roundSeconds: 60,
          category: 'mixed',
          wordsPerTurn: 0,
        );

        notifier.startRound();
        var state = container.read(charadesGameProvider);
        expect(state.isWordsLimitEnabled, isFalse);
        expect(state.currentWordNumberInTurn, equals(1));

        // نتخطى ونجاوب أكثر من 10 كلمات
        for (int i = 0; i < 12; i++) {
          if (i.isEven) {
            notifier.markCorrect();
          } else {
            notifier.markPass();
          }
        }

        state = container.read(charadesGameProvider);
        // الجولة ما زالت شغالة ولم تتوقف لأنها مفتوحة
        expect(state.isRoundActive, isTrue);
        expect(state.wordsAttemptedInRound, equals(12));
        expect(state.isWordsLimitReached, isFalse);
      },
    );

    test(
      '4. فلتر جودة الكلمات isActableCharadesWord يرفض المفاهيم المجردة ويقبل التمثيل',
      () {
        // كلمات مجردة وممنوعة
        expect(
          GameContentService.isActableCharadesWord('الديمقراطية'),
          isFalse,
        );
        expect(
          GameContentService.isActableCharadesWord('التضخم الاقتصادي'),
          isFalse,
        );
        expect(GameContentService.isActableCharadesWord('العولمة'), isFalse);
        expect(
          GameContentService.isActableCharadesWord(
            'الذكاء الاصطناعي التوليدي المعقد',
          ),
          isFalse,
        ); // > 4 كلمات
        expect(GameContentService.isActableCharadesWord(''), isFalse);

        // كلمات قابلة للتمثيل الحركي
        expect(GameContentService.isActableCharadesWord('طبيب أسنان'), isTrue);
        expect(
          GameContentService.isActableCharadesWord('غسيل الأطباق'),
          isTrue,
        );
        expect(
          GameContentService.isActableCharadesWord('الهروب من السجن'),
          isTrue,
        );
        expect(
          GameContentService.isActableCharadesWord('الفيل الأزرق'),
          isTrue,
        );
        expect(GameContentService.isActableCharadesWord('ركوب العجلة'), isTrue);
        expect(
          GameContentService.isActableCharadesWord('النمر الأسود'),
          isTrue,
        );
      },
    );

    test(
      '5. بنك الكلمات CharadesWordsBank يحتوي على أكثر من 100 كلمة قابلة للتمثيل لكل قسم',
      () {
        final categories = [
          'movies',
          'series',
          'actions',
          'jobs',
          'animals',
          'places',
          'things',
          'proverbs',
          'mixed',
        ];

        for (final cat in categories) {
          final words = CharadesWordsBank.getWordsForCategory(cat);
          expect(
            words.length,
            greaterThanOrEqualTo(100),
            reason: 'القسم $cat يجب أن يحتوي على 100 كلمة على الأقل',
          );

          // كل كلمة في البنك يجب أن تحقق معيار التمثيل الحركي
          for (final w in words) {
            expect(
              GameContentService.isActableCharadesWord(w),
              isTrue,
              reason:
                  'الكلمة "$w" في قسم $cat يجب أن تكون قابلة للتمثيل الحركي دون كلام',
            );
          }
        }
      },
    );

    test(
      '6. جلب كلمات قسم محدد يعيد كلمات خاصة بهذا القسم دون خلط خاطئ',
      () async {
        // جلب كلمات حيوانات
        final animalWords = await contentService.getCharadesWords(
          count: 20,
          category: 'animals',
        );
        expect(animalWords.length, equals(20));
        // نتأكد أن الكلمات من قسم الحيوانات
        for (final w in animalWords) {
          expect(CharadesWordsBank.animals.contains(w), isTrue);
        }

        // جلب كلمات مسلسلات
        final seriesWords = await contentService.getCharadesWords(
          count: 20,
          category: 'series',
        );
        expect(seriesWords.length, equals(20));
        for (final w in seriesWords) {
          expect(CharadesWordsBank.series.contains(w), isTrue);
        }
      },
    );

    test(
      '7. انتهاء الدور بانتهاء الوقت أيهما أسبق (قبل الوصول للعدد المختار من الكلمات)',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localStorageProvider.overrideWithValue(storage),
            gameContentServiceProvider.overrideWithValue(contentService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(charadesGameProvider.notifier);
        // نحدد 20 كلمة ولكن الوقت ثانية واحدة فقط
        await notifier.initGame(
          roundsPerPlayer: 1,
          roundSeconds: 1,
          wordsPerTurn: 20,
        );

        notifier.startRound();
        var state = container.read(charadesGameProvider);
        expect(state.isRoundActive, isTrue);

        // جاوب كلمة واحدة فقط
        notifier.markCorrect();
        state = container.read(charadesGameProvider);
        expect(state.wordsAttemptedInRound, equals(1));
        expect(state.isWordsLimitReached, isFalse);

        // ننتظر ثانية وربع لانتهاء مؤقت الجولة
        await Future.delayed(const Duration(milliseconds: 1200));

        state = container.read(charadesGameProvider);
        // الدور ينتهي بانتهاء الوقت أسبق من الكلمات
        expect(state.isRoundActive, isFalse);
        expect(state.secondsLeft, equals(0));
        expect(state.wordsAttemptedInRound, equals(1));
      },
    );

    test(
      '8. مزامنة إعداد wordsPerTurn مع باقي اللاعبين عبر الشبكة دون تعديلهم لها',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localStorageProvider.overrideWithValue(storage),
          ],
        );
        addTearDown(container.dispose);

        final roomNotifier = container.read(gameRoomProvider.notifier);

        // محاكاة وصول رسالة تحديث إعدادات من المضيف عبر السيرفر
        roomNotifier.updateFromNetwork({
          'settings': {
            'words_per_turn': 15,
            'round_seconds': 90,
            'category': 'actions',
          },
        });

        final clientSettings = container.read(charadesSettingsProvider);
        expect(clientSettings.wordsPerTurn, equals(15));
        expect(clientSettings.roundSeconds, equals(90));
        expect(clientSettings.category, equals('actions'));
      },
    );

    test(
      '9. ملخص الدور يحسب بدقة المعروضة وعرفوها وتخطي وإخفاء العدّاد عند "مفتوح"',
      () {
        // حالة مع حد 10 كلمات
        const limitedState = CharadesGameState(
          wordsPerTurn: 10,
          roundHistory: [
            {'word': 'الناظر', 'correct': true},
            {'word': 'الكيف', 'correct': false},
            {'word': 'بوحة', 'correct': true},
          ],
        );

        expect(limitedState.isWordsLimitEnabled, isTrue);
        expect(limitedState.wordsAttemptedInRound, equals(3));
        expect(limitedState.correctCountInRound, equals(2));
        expect(limitedState.passedCountInRound, equals(1));
        expect(limitedState.currentWordNumberInTurn, equals(4));

        // حالة مفتوح (بلا حد = 0)
        const openState = CharadesGameState(
          wordsPerTurn: 0,
          roundHistory: [
            {'word': 'الناظر', 'correct': true},
            {'word': 'الكيف', 'correct': false},
          ],
        );

        expect(openState.isWordsLimitEnabled, isFalse);
        expect(openState.wordsAttemptedInRound, equals(2));
        expect(openState.correctCountInRound, equals(1));
        expect(openState.passedCountInRound, equals(1));
      },
    );
  });
}
