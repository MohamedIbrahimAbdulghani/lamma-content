// Lamma - by Mohamed Ibrahim
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/main.dart';
import 'package:lamma_party_game_app/net/protocol/game_message.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';

void main() {
  group('Lamma Core Unit Tests', () {
    test('GameMessage serialization and deserialization', () {
      const msg = GameMessage(
        type: 'join',
        payload: {'room_code': '1234', 'name': 'أحمد'},
      );
      final jsonStr = msg.serialize();
      final parsed = GameMessage.deserialize(jsonStr);

      expect(parsed, isNotNull);
      expect(parsed!.type, equals('join'));
      expect(parsed.payload['room_code'], equals('1234'));
      expect(parsed.payload['name'], equals('أحمد'));
    });

    test('PlayerModel serialization and strikes tracking', () {
      final player = PlayerModel(
        id: 'p1',
        name: 'سارة',
        avatar: '🦊',
        score: 100,
        strikes: 2,
        isHost: false,
      );

      final json = player.toJson();
      final fromJson = PlayerModel.fromJson(json);

      expect(fromJson.id, equals('p1'));
      expect(fromJson.name, equals('سارة'));
      expect(fromJson.avatar, equals('🦊'));
      expect(fromJson.strikes, equals(2));
      expect(fromJson.isKicked, isFalse);

      final kickedPlayer = fromJson.copyWith(strikes: 3, isKicked: true);
      expect(kickedPlayer.isKicked, isTrue);
      expect(kickedPlayer.strikes, equals(3));
    });

    test('QuestionModel parsing test', () {
      const q = QuestionModel(
        id: 1,
        categoryId: 3,
        categorySlug: 'afeehat',
        type: 'mcq',
        promptAr: 'مين صاحب الإفيه؟',
        options: ['عادل إمام', 'محمد هنيدي', 'أحمد حلمي', 'سمير غانم'],
        correctIndex: 1,
        difficulty: 'medium',
        source: 'seed',
      );

      final json = q.toJson();
      final parsed = QuestionModel.fromJson(json);

      expect(parsed.id, equals(1));
      expect(parsed.promptAr, equals('مين صاحب الإفيه؟'));
      expect(parsed.options.length, equals(4));
      expect(parsed.correctIndex, equals(1));
    });

    test('SpySettings validation clamps', () {
      final notifier = SpySettingsNotifier();
      notifier.update(rounds: 15); // > 10, should stay 3
      expect(notifier.state.rounds, equals(3));

      notifier.update(rounds: 5);
      expect(notifier.state.rounds, equals(5));

      notifier.update(discussionMinutes: 20); // > 15, should stay 5
      expect(notifier.state.discussionMinutes, equals(5));

      notifier.update(discussionMinutes: 7);
      expect(notifier.state.discussionMinutes, equals(7));
    });

    test('TriviaSettings toggle categories', () {
      final notifier = TriviaSettingsNotifier();
      expect(notifier.state.categories.contains('movies'), isTrue);

      notifier.toggleCategory('movies');
      expect(notifier.state.categories.contains('movies'), isFalse);

      notifier.toggleCategory('movies');
      expect(notifier.state.categories.contains('movies'), isTrue);
    });

    test('CharadesSettings bounds checking', () {
      final notifier = CharadesSettingsNotifier();
      notifier.update(roundSeconds: 200); // > 180, should stay 60
      expect(notifier.state.roundSeconds, equals(60));

      notifier.update(roundSeconds: 90);
      expect(notifier.state.roundSeconds, equals(90));
    });
  });

  testWidgets('App basic smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const LammaApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(LammaApp), findsOneWidget);
  });
}
