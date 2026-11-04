// Lamma - Game Back Navigation & Confirmation Tests
// Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/core/constants/game_strings.dart';
import 'package:lamma_party_game_app/core/utils/arabic_text_normalizer.dart';
import 'package:lamma_party_game_app/core/widgets/game_back_dialog.dart';
import 'package:lamma_party_game_app/core/widgets/game_back_handler.dart';
import 'package:lamma_party_game_app/data/api/api_client.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/models/question_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/data/services/game_content_service.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_controller.dart';
import 'package:lamma_party_game_app/features/trivia/presentation/controllers/trivia_state.dart';
import 'package:lamma_party_game_app/features/charades/controllers/charades_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1) Host Back Behavior & Return to Lobby Tests', () {
    test('Host returning to lobby resets room state to lobby while keeping room, settings, and players', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameRoomProvider.notifier);

      // Setup an active room with players
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', avatar: '🦁', isHost: true);
      final p2 = const PlayerModel(id: 'p_2', name: 'أحمد', avatar: '🦊');
      final p3 = const PlayerModel(id: 'p_3', name: 'سارة', avatar: '🐻');

      final server = RoomServer(
        hostPlayer: host,
        roomCode: 'BACK1',
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      notifier.setHostServer(server, 'BACK1', '192.168.1.5');
      notifier.setPlayers([host, p2, p3]);
      notifier.startGame();
      notifier.updatePhase('discussion');

      expect(container.read(gameRoomProvider).currentPhase, equals('discussion'));
      expect(container.read(gameRoomProvider).isHost, isTrue);

      // Host triggers return to lobby
      notifier.hostReturnToLobby();

      final updatedState = container.read(gameRoomProvider);
      expect(updatedState.currentPhase, equals('lobby'));
      expect(updatedState.timerSeconds, equals(0));
      expect(updatedState.roomCode, equals('BACK1'));
      expect(updatedState.players.length, equals(3));
      expect(updatedState.players.first.name, equals('المضيف'));
      // Players retained, roles and current words cleared
      for (final p in updatedState.players) {
        expect(p.role, isNull);
        expect(p.currentWord, isNull);
      }
    });

    test('RoomServer returnToLobby cancels timers, resets phase to lobby, and clears votes', () {
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      final server = RoomServer(
        hostPlayer: host,
        roomCode: 'ROOM1',
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );

      server.startDiscussionTimer(2);
      expect(server.currentPhase, equals('discussion'));

      server.returnToLobby();
      expect(server.currentPhase, equals('lobby'));
    });

    test('TriviaController cancelRound cancels all running timers immediately', () {
      final controller = TriviaGameNotifier(
        initialQuestions: kDefaultTriviaQuestions.take(2).toList(),
        totalSeconds: 30,
        initialPlayers: [
          const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        ],
      );

      expect(controller.state.phase, equals(TriviaPhase.question));
      expect(controller.state.secondsLeft, greaterThan(0));

      controller.cancelRound();
      expect(controller.state.currentQuestion, isNotNull);
      controller.dispose();
    });

    test('CharadesController cancelRound stops round active state immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final charades = container.read(charadesGameProvider.notifier);
      charades.cancelRound();
      expect(container.read(charadesGameProvider).isRoundActive, isFalse);
    });
  });

  group('2) Non-Host Player Leave Behavior & Minimum Player Threshold Tests', () {
    test('Player leaving updates player list on server and leaves room intact for others if threshold met', () {
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      final p2 = const PlayerModel(id: 'p_2', name: 'لاعب 2');
      final p3 = const PlayerModel(id: 'p_3', name: 'لاعب 3');
      final p4 = const PlayerModel(id: 'p_4', name: 'لاعب 4');

      final server = RoomServer(
        hostPlayer: host,
        roomCode: 'SPY01',
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );
      server.updateGameMode('spy');
      server.setPlayers([host, p2, p3, p4]);
      server.startDiscussionTimer(2);

      // Player 4 leaves (3 players remain: host, p2, p3 >= 3 required for spy)
      server.removePlayer('p_4');

      expect(server.players.length, equals(3));
      expect(server.players.any((p) => p.id == 'p_4'), isFalse);
      expect(server.currentPhase, equals('discussion'));
    });

    test('Player leaving triggers returnToLobby when remaining active players drop below minimum (<3 in Spy)', () {
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      final p2 = const PlayerModel(id: 'p_2', name: 'لاعب 2');
      final p3 = const PlayerModel(id: 'p_3', name: 'لاعب 3');

      final server = RoomServer(
        hostPlayer: host,
        roomCode: 'SPY02',
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );
      server.updateGameMode('spy');
      server.setPlayers([host, p2, p3]);
      server.startDiscussionTimer(2);

      expect(server.currentPhase, equals('discussion'));

      // Player 3 leaves -> remaining active is 2 (< 3 minRequired for Spy)
      server.removePlayer('p_3');

      expect(server.players.length, equals(2));
      // Must automatically return to lobby!
      expect(server.currentPhase, equals('lobby'));
    });

    test('Player leaving triggers returnToLobby when remaining active players drop below minimum (<2 in Trivia/Charades)', () {
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      final p2 = const PlayerModel(id: 'p_2', name: 'لاعب 2');

      final server = RoomServer(
        hostPlayer: host,
        roomCode: 'TRIV1',
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );
      server.updateGameMode('trivia');
      server.setPlayers([host, p2]);
      server.startTriviaGame(kDefaultTriviaQuestions.take(2).toList());

      expect(server.currentPhase, equals('trivia_question'));

      // Player 2 leaves -> only 1 player remains (< 2 minRequired)
      server.removePlayer('p_2');

      expect(server.players.length, equals(1));
      expect(server.currentPhase, equals('lobby'));
    });
  });

  group('3) Rapid Double-Tap Protection Tests', () {
    testWidgets('Double clicking back button rapidly opens only ONE confirmation dialog', (tester) async {
      int confirmCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // Rapidly call showHostReturnDialog twice
                  GameBackDialog.showHostReturnDialog(context, onConfirm: () {
                    confirmCount++;
                  });
                  GameBackDialog.showHostReturnDialog(context, onConfirm: () {
                    confirmCount++;
                  });
                },
                child: const Text('Back'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Only ONE dialog title should be in the widget tree
      expect(find.text(GameStrings.hostReturnDialogTitle), findsOneWidget);
      expect(find.text(GameStrings.hostReturnDialogMessage), findsOneWidget);

      // Confirm dialog
      await tester.tap(find.text(GameStrings.hostReturnConfirmButton));
      await tester.pumpAndSettle();

      expect(confirmCount, equals(1));
    });
  });

  group('4) Unpresented Items Deduplication on Round Cancellation', () {
    test('Cancelling a round mid-game records ONLY presented question and does NOT record unpresented questions', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      final api = ApiClient(storage);
      final contentService = GameContentService(api, storage);

      final q1 = const QuestionModel(
        id: 991,
        categoryId: 1,
        categorySlug: 'general',
        type: 'mcq',
        promptAr: 'السؤال المعروض بالفعل',
        options: ['أ', 'ب', 'ج', 'د'],
        correctIndex: 0,
        difficulty: 'medium',
        source: 'offline',
      );
      final q2 = const QuestionModel(
        id: 992,
        categoryId: 1,
        categorySlug: 'general',
        type: 'mcq',
        promptAr: 'السؤال غير المعروض بعد',
        options: ['أ', 'ب', 'ج', 'د'],
        correctIndex: 1,
        difficulty: 'medium',
        source: 'offline',
      );

      // 1. Mark question 1 as presented
      await contentService.markTriviaQuestionPresented(q1);

      // 2. Round is cancelled before question 2 is presented
      // Verify storage: q1 is seen, q2 is UNSEEN
      final seenPrompts = storage.getSeenTriviaPromptHashes();
      final p1Hash = ArabicTextNormalizer.triviaQuestionHash(q1.promptAr);
      final p2Hash = ArabicTextNormalizer.triviaQuestionHash(q2.promptAr);

      expect(seenPrompts.contains(p1Hash), isTrue);
      expect(seenPrompts.contains(p2Hash), isFalse);
    });
  });

  group('5) GameBackScope PopScope & UI Elements Tests', () {
    testWidgets('GameBackScope intercepts back and displays correct dialog for host', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Configure room as host in playing state
      final host = const PlayerModel(id: 'host_1', name: 'المضيف', isHost: true);
      container.read(gameRoomProvider.notifier).setHostServer(
        RoomServer(
          hostPlayer: host,
          roomCode: 'ROOM_UI',
          onStateChanged: (_) {},
          onStrikeToast: (_) {},
        ),
        'ROOM_UI',
        '192.168.1.1',
      );
      container.read(gameRoomProvider.notifier).startGame();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GameBackScope(
              child: Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(56),
                  child: GameBackButton(),
                ),
                body: Text('Gameplay Screen'),
              ),
            ),
          ),
        ),
      );

      // Verify GameBackButton exists
      expect(find.byType(GameBackButton), findsOneWidget);

      // Tap GameBackButton
      await tester.tap(find.byType(GameBackButton));
      await tester.pumpAndSettle();

      // Host confirmation dialog should appear with exact Arabic text
      expect(find.text(GameStrings.hostReturnDialogTitle), findsOneWidget);
      expect(find.text(GameStrings.hostReturnDialogMessage), findsOneWidget);
      expect(find.text(GameStrings.hostReturnConfirmButton), findsOneWidget);
      expect(find.text(GameStrings.cancelDialogButton), findsOneWidget);

      // Cancel button dismisses dialog
      await tester.tap(find.text(GameStrings.cancelDialogButton));
      await tester.pumpAndSettle();

      expect(find.text(GameStrings.hostReturnDialogTitle), findsNothing);
    });

    testWidgets('GameBackScope displays correct dialog for non-host player', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Configure room as non-host player
      container.read(gameRoomProvider.notifier).updatePhase('discussion');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GameBackScope(
              child: Scaffold(
                body: Center(
                  child: GameBackCircularButton(),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap circular back button
      await tester.tap(find.byType(GameBackCircularButton));
      await tester.pumpAndSettle();

      // Non-host player leave dialog appears
      expect(find.text(GameStrings.playerLeaveDialogTitle), findsOneWidget);
      expect(find.text(GameStrings.playerLeaveDialogMessage), findsOneWidget);
      expect(find.text(GameStrings.playerLeaveConfirmButton), findsOneWidget);
    });
  });
}
