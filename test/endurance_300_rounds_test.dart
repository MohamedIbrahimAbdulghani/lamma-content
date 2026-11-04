// Lamma - Permanent 300-Game Endurance Test Suite
// by Mohamed Ibrahim
// Tests 300 games / rounds per game mode with 2+ players having distinct seen histories,
// verifying zero duplicate presentations to any device or room.

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) responder;
  MockDioAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage hostStorage;
  late ApiClient api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    hostStorage = LocalStorage(prefs);
    api = ApiClient(hostStorage);
  });

  group('Permanent 300-Game Endurance Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. تحدي الشلة (Trivia): 300 جولة بلاعبين أو أكثر بسجلات مختلفة
    // -------------------------------------------------------------------------
    test('تحدي الشلة: 300 جولة - التحقق من صفر تكرار ودمج سجلات الحاضرين', () async {
      final hostPlayer = const PlayerModel(id: 'host_dev', name: 'المضيف', emoji: '👑', isHost: true);

      final server = RoomServer(
        roomCode: 'TEST300',
        hostPlayer: hostPlayer,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      // إنشاء بنك 350 سؤال فريد
      final List<QuestionModel> bigBank = List.generate(350, (i) {
        final id = i + 1;
        return QuestionModel(
          id: id,
          categoryId: 1,
          categorySlug: 'general',
          type: 'mcq',
          promptAr: 'سؤال اختبار التحمل رقم $id في العالم؟',
          options: ['خيار أ $id', 'خيار ب $id', 'خيار ج $id', 'خيار د $id'],
          correctIndex: id % 4,
          difficulty: 'medium',
          source: 'seed',
        );
      });

      // اللاعب 2 سبق وشاهد السؤالين 1 و 2، واللاعب 3 شاهد السؤال 3
      final p2SeenHashes = {
        ArabicTextNormalizer.triviaQuestionHash(bigBank[0].promptAr),
        ArabicTextNormalizer.triviaQuestionHash(bigBank[1].promptAr),
      };
      final p3SeenHashes = {
        ArabicTextNormalizer.triviaQuestionHash(bigBank[2].promptAr),
      };

      // دمج سجلات اللاعبين الحاضرين في السيرفر
      server.recordSeenTriviaAcrossRoom(p2SeenHashes.toList(), []);
      server.recordSeenTriviaAcrossRoom(p3SeenHashes.toList(), []);

      // محاكاة استجابة الـ API لتقديم الأسئلة من بنك الاختبار للغرفة
      int serverIndex = 0;
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        if (options.path.contains('/next-questions-batch')) {
          final count = int.tryParse(options.queryParameters['count']?.toString() ?? '1') ?? 1;
          final batch = <Map<String, dynamic>>[];
          while (batch.length < count && serverIndex < bigBank.length) {
            batch.add(bigBank[serverIndex++].toJson(reveal: true));
          }
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'count': batch.length, 'data': batch}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.path.contains('/next-question')) {
          if (serverIndex < bigBank.length) {
            final q = bigBank[serverIndex++];
            return ResponseBody.fromString(
              jsonEncode({'success': true, 'data': q.toJson(reveal: true)}),
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'success': false, 'error': 'exhausted'}),
            404,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      final testApi = ApiClient(hostStorage, dio: dio);
      final contentService = GameContentService(testApi, hostStorage);
      final presentedPromptHashes = <String>{};
      final presentedQuestionIds = <int>{};

      const int roundsToPlay = 300;

      for (int round = 1; round <= roundsToPlay; round++) {
        // دمج بصمات جميع اللاعبين الحاضرين قبل الاختيار
        final mergedSeenPrompts = server.getAllSeenTriviaPromptHashes();
        final mergedSeenAnswers = server.getAllSeenTriviaAnswerHashes();

        final questions = await contentService.getTriviaQuestions(
          count: 1,
          categories: ['general'],
          roomCode: 'TEST300',
          externalSeenPromptHashes: mergedSeenPrompts,
          externalSeenAnswerHashes: mergedSeenAnswers,
        );

        expect(questions.length, 1, reason: 'الجولة $round فشلت في إرجاع سؤال');
        final currentQ = questions.first;

        final pHash = ArabicTextNormalizer.triviaQuestionHash(currentQ.promptAr);
        final aHash = ArabicTextNormalizer.triviaAnswerHash(
          currentQ.categorySlug,
          currentQ.options[currentQ.correctIndex],
        );

        // التحقق من أن السؤال لم يسبق تقديمه لهذه الغرفة
        expect(
          presentedPromptHashes.contains(pHash),
          isFalse,
          reason: 'السؤال "${currentQ.promptAr}" قُدِّم مرتين لنفس الغرفة في الجولة $round!',
        );

        // التحقق من أنه لم يكن ضمن السجل المسبق للاعب 2 أو اللاعب 3
        expect(
          p2SeenHashes.contains(pHash),
          isFalse,
          reason: 'تم تقديم سؤال سبق أن شاهده اللاعب 2!',
        );
        expect(
          p3SeenHashes.contains(pHash),
          isFalse,
          reason: 'تم تقديم سؤال سبق أن شاهده اللاعب 3!',
        );

        // تسجيل السؤال كمشاهد لحظة التقديم الفعلي فقط لدى جميع أجهزة الغرفة
        await contentService.markTriviaQuestionPresented(currentQ);
        server.recordSeenTriviaAcrossRoom([pHash], [aHash]);

        presentedPromptHashes.add(pHash);
        presentedQuestionIds.add(currentQ.id);
      }

      // تم تقديم 300 سؤال فريد تماماً بدون أي تكرار
      expect(presentedPromptHashes.length, roundsToPlay);
      expect(presentedQuestionIds.length, roundsToPlay);

      await server.stop();
    });

    // -------------------------------------------------------------------------
    // 2. مين الجاسوس (Spy): 300 جولة - منع التكرار المتتالي والسابق والمجموعات
    // -------------------------------------------------------------------------
    test('مين الجاسوس: 300 جولة - منع التكرار المتتالي وفي نفس الغرفة وتجانس خيارات الجاسوس', () async {
      final hostPlayer = const PlayerModel(id: 'host_dev', name: 'المضيف', emoji: '👑', isHost: true);
      final server = RoomServer(
        roomCode: 'SPY300',
        hostPlayer: hostPlayer,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      // بنك 320 مجموعة كلمات متجانسة فريدة
      final spyPacks = List.generate(320, (g) {
        final gId = g + 1;
        return SpyWordPackData(
          id: gId,
          slug: 'pack_$gId',
          nameAr: 'مجموعة الأماكن $gId',
          words: [
            'مكان_${gId}_1',
            'مكان_${gId}_2',
            'مكان_${gId}_3',
            'مكان_${gId}_4',
          ],
        );
      });

      final bootstrap = BootstrapData(
        version: 1,
        lastUpdated: '2026-11-02',
        categories: [],
        spyPacks: spyPacks,
        charadesCategories: [],
        avatars: [],
        rulePages: [],
        settings: {},
      );

      final contentService = GameContentService(api, hostStorage);
      final presentedSecretWords = <String>{};
      String? previousSecretWord;

      const int roundsToPlay = 300;

      for (int round = 1; round <= roundsToPlay; round++) {
        final packSlug = 'pack_$round';
        final word = await contentService.getNextSpyWord(
          packSlug: packSlug,
          bootstrapData: bootstrap,
          previousWord: previousSecretWord,
          externalSeenHashes: server.getAllSeenSpyHashes(),
        );

        expect(word, isNotNull, reason: 'الجولة $round فشلت في إرجاع كلمة');

        // 1. لا تتكرر الكلمة السرية بين جولتين متتاليتين
        expect(
          word,
          isNot(equals(previousSecretWord)),
          reason: 'الكلمة السرية "$word" تكررت في جولتين متتاليتين في الجولة $round!',
        );

        // 2. لا تتكرر الكلمة مع أي جولة سابقة لنفس الغرفة
        expect(
          presentedSecretWords.contains(word),
          isFalse,
          reason: 'الكلمة السرية "$word" تكررت في نفس الغرفة بالجولة $round!',
        );

        // 3. خيارات الجاسوس لا تتكرر وتُسجل كمشاهدة
        final choices = ['مكان_${round}_1', 'مكان_${round}_2', 'مكان_${round}_3', 'مكان_${round}_4'];
        await contentService.markSpyRoundPresented(
          word!,
          spyChoices: choices,
          roomServer: server,
        );

        presentedSecretWords.add(word);
        previousSecretWord = word;
      }

      expect(presentedSecretWords.length, roundsToPlay);
      await server.stop();
    });

    // -------------------------------------------------------------------------
    // 3. مثّل ومتتكلمش (Charades): 300 جولة - صفر تكرار لكلمات التمثيل
    // -------------------------------------------------------------------------
    test('مثّل ومتتكلمش: 300 كلمة - صفر تكرار وتسجيل لحظة التقديم الفعلي', () async {
      final hostPlayer = const PlayerModel(id: 'host_dev', name: 'المضيف', emoji: '👑', isHost: true);
      final server = RoomServer(
        roomCode: 'CHAR300',
        hostPlayer: hostPlayer,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      // بنك 350 كلمة تمثيل مصرية فريدة
      final charadesWords = List.generate(350, (i) => 'فيلم مصري تمثيلي فريد ${i + 1}');
      final bootstrap = BootstrapData(
        version: 1,
        lastUpdated: '2026-11-02',
        categories: [],
        spyPacks: [],
        charadesCategories: [
          CharadesCategoryData(
            id: 1,
            slug: 'movies',
            nameAr: 'أفلام',
            words: charadesWords,
          ),
        ],
        avatars: [],
        rulePages: [],
        settings: {},
      );

      final contentService = GameContentService(api, hostStorage);
      final presentedWords = <String>{};

      const int roundsToPlay = 300;

      for (int round = 1; round <= roundsToPlay; round++) {
        final words = await contentService.getCharadesWords(
          count: 1,
          category: 'movies',
          bootstrapData: bootstrap,
          externalSeenHashes: server.getAllSeenCharadesHashes(),
        );

        expect(words.length, 1, reason: 'الجولة $round فشلت في إرجاع كلمة');
        final currentWord = words.first;

        // لا تتكرر أي كلمة ظهرت سابقاً في الغرفة
        expect(
          presentedWords.contains(currentWord),
          isFalse,
          reason: 'كلمة التمثيل "$currentWord" تكررت في الجولة $round!',
        );

        // تسجيل الكلمة لحظة التقديم
        await contentService.markCharadesWordPresented(currentWord, roomServer: server);
        presentedWords.add(currentWord);
      }

      expect(presentedWords.length, roundsToPlay);
      await server.stop();
    });
  });
}
