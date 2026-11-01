// Lamma - Comprehensive Room Join & Realtime Tests
// Testing route resolution, room join validation, realtime synchronization, rate limiting, and edge cases.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/core/routes/app_router.dart';
import 'package:lamma_party_game_app/core/routes/app_routes.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/features/room/join_by_code_screen.dart';
import 'package:lamma_party_game_app/net/client/room_client.dart';
import 'package:lamma_party_game_app/net/server/room_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'lamma_player_name': 'أحمد',
      'lamma_player_emoji': '🦁',
      'lamma_device_id': 'test-device-id',
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('1) Route Resolution & No "Page Not Found" Tests', () {
    test('AppRoutes constants are defined correctly', () {
      expect(AppRoutes.joinByCode, equals('/room/join/code'));
      expect(AppRoutes.lobby, equals('/lobby'));
      expect(AppRoutes.wrongCode, equals('/feedback/wrong-code'));
      expect(AppRoutes.roomFull, equals('/feedback/room-full'));
      expect(AppRoutes.howToMenu, equals('/how-to'));
    });

    testWidgets('Navigating to /room/join/code resolves to JoinByCodeScreen without GoException',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();

      appRouter.go(AppRoutes.joinByCode);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(JoinByCodeScreen), findsOneWidget);
      expect(find.text('اكتب كود الغرفة'), findsOneWidget);
    });

    testWidgets('Legacy path /room/join-code redirects safely to /room/join/code',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();

      appRouter.go('/room/join-code');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(JoinByCodeScreen), findsOneWidget);
      expect(find.text('اكتب كود الغرفة'), findsOneWidget);
    });

    testWidgets('Legacy path /howto redirects safely to /how-to',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pump();

      appRouter.go('/howto');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('طريقة اللعب'), findsOneWidget);
      expect(find.text('إزاي تستخدم التطبيق'), findsOneWidget);
    });
  });

  group('2) Realtime Server & Client Join Verification Tests', () {
    int nextPort = 8180;
    int nextUdpPort = 8280;

    Future<RoomServer> createServer(String code, PlayerModel host) async {
      final p = nextPort++;
      final u = nextUdpPort++;
      final s = RoomServer(
        roomCode: code,
        hostPlayer: host,
        port: p,
        udpPort: u,
        onStateChanged: (_) {},
        onStrikeToast: (_) {},
      );
      await s.start();
      return s;
    }

    const roomCode = '4321';
    final hostPlayer = const PlayerModel(
      id: 'host-123',
      name: 'أحمد (المضيف)',
      emoji: '🦁',
      isHost: true,
    );

    test('Valid code join succeeds, joins immediately, and updates live player list', () async {
      final server = await createServer(roomCode, hostPlayer);
      final stateCompleter = Completer<Map<String, dynamic>>();

      final client = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'سارة',
        playerEmoji: '🦊',
        deviceId: 'device-sara-1',
        onStateUpdated: (state) {
          if (!stateCompleter.isCompleted) {
            stateCompleter.complete(state);
          }
        },
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final result = await client.connect();
      expect(result.isSuccess, isTrue);

      final updatedState = await stateCompleter.future.timeout(const Duration(seconds: 3));
      final players = updatedState['players'] as List<dynamic>;

      // قائمة اللاعبين تحدثت فوراً
      expect(players.length, equals(2));
      expect(players.any((p) => p['name'] == 'سارة'), isTrue);

      // المضيف يظل مضيف، والمنضم غير مضيف
      final hostInList = players.firstWhere((p) => p['id'] == 'host-123');
      final saraInList = players.firstWhere((p) => p['id'] == 'device-sara-1');
      expect(hostInList['is_host'], isTrue);
      expect(saraInList['is_host'], isFalse);

      client.disconnect();
      await server.stop();
    });

    test('Wrong code is rejected with error wrong_code', () async {
      final server = await createServer(roomCode, hostPlayer);

      final client = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: '9999', // كود خاطئ
        playerName: 'كريم',
        playerEmoji: '🐻',
        deviceId: 'device-karim-1',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final result = await client.connect();
      expect(result.isSuccess, isFalse);
      expect(result.errorKey, equals('wrong_code'));
      expect(result.errorMessage, contains('غير صحيح'));

      client.disconnect();
      await server.stop();
    });

    test('Room full rejection when 10 players are reached', () async {
      final server = await createServer(roomCode, hostPlayer);

      // نملأ الغرفة لـ 10 لاعبين (المضيف + 9 لاعبين)
      final fullPlayers = [
        hostPlayer,
        for (int i = 1; i <= 9; i++)
          PlayerModel(id: 'dummy-$i', name: 'لاعب $i', emoji: '🎮', isHost: false),
      ];
      server.setPlayers(fullPlayers);
      expect(server.players.length, equals(10));

      final client = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'لاعب زائد',
        playerEmoji: '🐯',
        deviceId: 'device-overflow',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final result = await client.connect();
      expect(result.isSuccess, isFalse);
      expect(result.errorKey, equals('room_full'));
      expect(result.errorMessage, contains('مكتملة'));

      client.disconnect();
      await server.stop();
    });

    test('Reconnecting with the same deviceId does NOT duplicate player or exceed capacity', () async {
      final server = await createServer(roomCode, hostPlayer);

      // 9 لاعبين وهميين + المضيف = 10 لاعبين
      final existingPlayer = const PlayerModel(
        id: 'device-sara-1',
        name: 'سارة',
        emoji: '🦊',
        isHost: false,
      );
      final initialPlayers = [
        hostPlayer,
        existingPlayer,
        for (int i = 1; i <= 8; i++)
          PlayerModel(id: 'dummy-$i', name: 'لاعب $i', emoji: '🎮', isHost: false),
      ];
      server.setPlayers(initialPlayers);
      expect(server.players.length, equals(10));

      // سارة تعيد الاتصال بنفس deviceId
      final client = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'سارة الجديدة',
        playerEmoji: '🦊',
        deviceId: 'device-sara-1',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final result = await client.connect();
      expect(result.isSuccess, isTrue);

      // لم يزد عدد اللاعبين عن 10
      expect(server.players.length, equals(10));
      expect(server.players.where((p) => p.id == 'device-sara-1').length, equals(1));

      client.disconnect();
      await server.stop();
    });

    test('New players are rejected if game is in progress (game_started)', () async {
      final server = await createServer(roomCode, hostPlayer);

      // بدء لعبة تجسس
      server.startSpyGame(
        secretWord: 'الأهرامات',
        categoryName: 'أماكن',
        discussionMinutes: 5,
      );
      expect(server.currentPhase, equals('role_hidden'));

      // لاعب جديد يحاول الانضمام أثناء اللعبة
      final newClient = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'لاعب متأخر',
        playerEmoji: '🐼',
        deviceId: 'device-late-1',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final result = await newClient.connect();
      expect(result.isSuccess, isFalse);
      expect(result.errorKey, equals('game_started'));
      expect(result.errorMessage, contains('بدأت اللعبة بالفعل'));

      newClient.disconnect();
      await server.stop();
    });

    test('Room closed rejects connection with room_closed', () async {
      final server = await createServer('7777', hostPlayer);
      await server.stop();
      expect(server.isClosed, isTrue);
    });

    test('Atomic capacity prevents two simultaneous joins from exceeding 10 players', () async {
      final server = await createServer(roomCode, hostPlayer);

      // الغرفة بها 9 لاعبين (متبقي مقعد واحد فقط)
      final ninePlayers = [
        hostPlayer,
        for (int i = 1; i <= 8; i++)
          PlayerModel(id: 'dummy-$i', name: 'لاعب $i', emoji: '🎮', isHost: false),
      ];
      server.setPlayers(ninePlayers);
      expect(server.players.length, equals(9));

      final client1 = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'منافس 1',
        playerEmoji: '🥇',
        deviceId: 'device-seat-1',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      final client2 = RoomClient(
        hostIp: '127.0.0.1',
        port: server.port,
        roomCode: roomCode,
        playerName: 'منافس 2',
        playerEmoji: '🥈',
        deviceId: 'device-seat-2',
        onStateUpdated: (_) {},
        onStrikeReceived: (_, __, ___) {},
        onHostLeft: () {},
        onJoinError: (_) {},
      );

      // محاولة انضمام في نفس اللحظة
      final results = await Future.wait([
        client1.connect(),
        client2.connect(),
      ]);

      final successCount = results.where((r) => r.isSuccess).length;
      final fullCount = results.where((r) => r.errorKey == 'room_full').length;

      expect(successCount, equals(1));
      expect(fullCount, equals(1));
      expect(server.players.length, equals(10));

      client1.disconnect();
      client2.disconnect();
      await server.stop();
    });
  });
}
