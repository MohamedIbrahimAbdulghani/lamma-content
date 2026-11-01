// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/features/home/home_screen.dart';
import 'package:lamma_party_game_app/features/lobby/lobby_screen.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';
import 'package:lamma_party_game_app/net/client/room_client.dart';

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

  group('LobbyScreen Selected Game Card & Min Players Validation Tests', () {
    testWidgets('Lobby displays Selected Game Card without game selection pills',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(roomProvider.notifier).setSelectedGame(GameType.spy);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LobbyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'اللعبة المختارة' header is present
      expect(find.text('اللعبة المختارة'), findsOneWidget);

      // Selected game title is present
      expect(find.text('مين الجاسوس'), findsOneWidget);
      expect(find.text('دوّر على الجاسوس بينكم'), findsOneWidget);

      // Old 'اختر نوع اللعبة' section is removed from lobby view
      expect(find.text('اختر نوع اللعبة'), findsNothing);
    });

    testWidgets('Host and Non-Host do not see "تغيير" button in Lobby',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(roomProvider.notifier).setSelectedGame(GameType.spy);
      container.read(roomProvider.notifier).setHostServer(
            RoomServer(
              roomCode: '1234',
              hostPlayer: const PlayerModel(id: '1', name: 'أحمد', isHost: true),
              onStateChanged: (_) {},
              onStrikeToast: (_) {},
            ),
            '1234',
            '127.0.0.1',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LobbyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure 'تغيير' button is completely removed from Lobby
      expect(find.text('تغيير'), findsNothing);
    });

    testWidgets('Non-host player cannot see "تغيير" button or "ابدأ اللعبة"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Non-host client state
      container.read(roomProvider.notifier).setClient(
            RoomClient(
              hostIp: '127.0.0.1',
              roomCode: '5678',
              playerName: 'سارة',
              playerEmoji: '🦊',
              deviceId: '2',
              onStateUpdated: (_) {},
              onStrikeReceived: (a, b, c) {},
              onHostLeft: () {},
              onJoinError: (_) {},
            ),
            '5678',
            '127.0.0.1',
          );
      container.read(roomProvider.notifier).setSelectedGame(GameType.charades);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LobbyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-host sees the card read-only
      expect(find.text('اللعبة المختارة'), findsOneWidget);
      expect(find.text('مثّل ومتتكلمش'), findsOneWidget);

      // 'تغيير' is hidden
      expect(find.text('تغيير'), findsNothing);

      // 'ابدأ اللعبة' is hidden
      expect(find.text('ابدأ اللعبة'), findsNothing);

      // Waiting message is shown
      expect(find.text('في انتظار صاحب الغرفة يبدأ اللعبة...'), findsOneWidget);
    });

    testWidgets('Start Game button works with any number of players (even 1 or 2 players) and remains enabled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Host with only 2 players in Spy game
      container.read(roomProvider.notifier).setSelectedGame(GameType.spy);
      container.read(roomProvider.notifier).setHostServer(
            RoomServer(
              roomCode: '9999',
              hostPlayer: const PlayerModel(id: '1', name: 'أحمد', isHost: true),
              onStateChanged: (_) {},
              onStrikeToast: (_) {},
            ),
            '9999',
            '127.0.0.1',
          );
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LobbyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start button is present and enabled
      final startButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'ابدأ اللعبة'));
      expect(startButton.onPressed, isNotNull);
    });
  });
}
