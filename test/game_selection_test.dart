// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/features/home/home_screen.dart';

void main() {
  group('SelectedGame Provider & Flow Unit Tests', () {
    test('Default selectedGame is spy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedGame), equals(GameType.spy));
      expect(container.read(selectedGameProvider), equals(GameType.spy));
    });

    test('Updating selectedGame on Home changes state and carries through', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // User picks Trivia on Home
      container.read(selectedGame.notifier).state = GameType.trivia;
      expect(container.read(selectedGame), equals(GameType.trivia));

      // Room provider starts with that choice
      final roomState = container.read(roomProvider);
      expect(roomState.selectedGame, equals(GameType.trivia));
      expect(roomState.gameMode, equals('trivia'));
    });

    test('Host can change game in Lobby and it updates both providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pick Trivia first
      container.read(selectedGame.notifier).state = GameType.trivia;
      container.read(roomProvider.notifier).setSelectedGame(GameType.trivia);

      expect(container.read(selectedGame), equals(GameType.trivia));
      expect(container.read(roomProvider).selectedGame, equals(GameType.trivia));

      // Host changes game in Lobby to Charades
      container.read(selectedGame.notifier).state = GameType.charades;
      container.read(roomProvider.notifier).setSelectedGame(GameType.charades);

      expect(container.read(selectedGame), equals(GameType.charades));
      expect(container.read(roomProvider).selectedGame, equals(GameType.charades));
      expect(container.read(roomProvider).gameMode, equals('charades'));
    });

    test('leaveRoom does not reset selectedGame when navigating back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Select Charades
      container.read(selectedGame.notifier).state = GameType.charades;
      container.read(roomProvider.notifier).setSelectedGame(GameType.charades);

      // Simulate leave room on navigating back
      container.read(roomProvider.notifier).leaveRoom();

      // Ensure it never resets to default spy
      expect(container.read(selectedGame), equals(GameType.charades));
      expect(container.read(roomProvider).selectedGame, equals(GameType.charades));
      expect(container.read(roomProvider).gameMode, equals('charades'));
    });
  });

  group('HomeScreen Game Selection Widget Tests', () {
    testWidgets('Tapping game cards on HomeScreen updates selectedGame provider without resetting',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'player_name': 'أحمد',
        'player_emoji': '🦁',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default is spy
      expect(container.read(selectedGame), equals(GameType.spy));

      // Tap Trivia card ('تحدي الشلة')
      final triviaFinder = find.text('تحدي الشلة');
      expect(triviaFinder, findsOneWidget);
      await tester.tap(triviaFinder);
      await tester.pumpAndSettle();

      // Provider must update to trivia
      expect(container.read(selectedGame), equals(GameType.trivia));
      expect(container.read(roomProvider).selectedGame, equals(GameType.trivia));

      // Tap Charades card ('مثّل ومتتكلمش')
      final charadesFinder = find.text('مثّل ومتتكلمش');
      expect(charadesFinder, findsOneWidget);
      await tester.tap(charadesFinder);
      await tester.pumpAndSettle();

      // Provider must update to charades
      expect(container.read(selectedGame), equals(GameType.charades));
      expect(container.read(roomProvider).selectedGame, equals(GameType.charades));
    });
  });
}
