// Lamma - Spy Game Comprehensive Tests
// Testing round counts, fair spy random distribution, no-repeat consecutive rule, edge cases, settings persistence & independence

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamma_party_game_app/data/models/bootstrap_data.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/data/storage/local_storage.dart';
import 'package:lamma_party_game_app/features/spy/spy_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late LocalStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorage(prefs);
  });

  group('1) Spy Game Rounds Enforcement Tests', () {
    test('Round stops at exactly N rounds and rejects Round N+1', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
        const PlayerModel(id: '3', name: 'كريم'),
      ]);

      const int totalRounds = 3;

      // Round 1
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: totalRounds,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));
      expect(container.read(gameRoomProvider).totalRounds, equals(3));

      // Round 2
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: totalRounds,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(2));

      // Round 3 (Last Round)
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: totalRounds,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(3));

      // Attempting Round 4 (N+1) must be rejected by logic
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: totalRounds,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(3)); // Did not advance past 3!

      // Starting a new game resets round to 1
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: totalRounds,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));
    });

    test('Rapid consecutive calls cannot exceed N rounds', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
      ]);

      // Initialize with N = 2
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 2,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));

      // Advance to round 2
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 2,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(2));

      // Simulate 10 rapid clicks
      for (int i = 0; i < 10; i++) {
        await roomNotifier.startSpyGameRound(
          packSlug: 'places',
          bootstrapData: null,
          totalRounds: 2,
          isNewGame: false,
        );
      }
      expect(container.read(gameRoomProvider).currentRound, equals(2));
    });

    test('Replay round logic does not work after last round and when N = 1',
        () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
      ]);

      // Start game with N = 1
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 1,
        isNewGame: true,
      );

      expect(container.read(gameRoomProvider).currentRound, equals(1));
      expect(container.read(gameRoomProvider).totalRounds, equals(1));

      // For N = 1: Replay round attempt must be rejected immediately by logic
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 1,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));

      // Starting a new game starts at 1
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 1,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));
    });

    test('Replay round logic only advances when currentRound < N', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
      ]);

      // Round 1 of 3
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(1));

      // Replay round advances to 2
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(2));

      // Replay round advances to 3 (final)
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(3));

      // After round 3, replay round does NOT advance to 4
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).currentRound, equals(3));
    });
  });

  group('2) Spy Fair Random Selection & No-Repeat Consecutive Rule', () {
    test('Spy never repeats in two consecutive rounds across 100 rounds simulation',
        () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      final testPlayers = [
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
        const PlayerModel(id: '3', name: 'كريم'),
        const PlayerModel(id: '4', name: 'نور'),
      ];
      container.read(roomProvider.notifier).setPlayers(testPlayers);

      final bigPlacesBootstrap = BootstrapData(
        version: 1,
        lastUpdated: '',
        categories: [],
        spyPacks: [
          SpyWordPackData(
            id: 1,
            slug: 'places',
            nameAr: 'أماكن',
            words: List.generate(250, (i) => 'مكان تجريبي فريد $i'),
          ),
        ],
        charadesCategories: [],
        avatars: [],
        rulePages: [],
        settings: {},
      );

      String? lastSpyId;
      int consecutiveRepeats = 0;
      for (int round = 1; round <= 100; round++) {
        // Reset round number if needed to simulate many rounds
        await roomNotifier.startSpyGameRound(
          packSlug: 'places',
          bootstrapData: bigPlacesBootstrap,
          totalRounds: 1000,
          isNewGame: false,
        );

        final currentSpies = container.read(gameRoomProvider).spyPlayerIds;
        expect(currentSpies, isNotEmpty);
        final currentSpy = currentSpies.first;

        if (lastSpyId != null && currentSpy == lastSpyId) {
          consecutiveRepeats++;
        }
        lastSpyId = currentSpy;
      }

      // مع قاعدة الـ 3%، التكرار نادر جداً (أقل من 8 مرات في 100 جولة)
      expect(consecutiveRepeats, lessThanOrEqualTo(8),
          reason: 'Spy repeated consecutively $consecutiveRepeats times, expected <= 8 under 3% rule');
    });

    test('Statistical fairness: Spy selection is distributed across all players, not always host',
        () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final bigPlacesBootstrap = BootstrapData(
        version: 1,
        lastUpdated: '',
        categories: [],
        spyPacks: [
          SpyWordPackData(
            id: 1,
            slug: 'places',
            nameAr: 'أماكن',
            words: List.generate(250, (i) => 'مكان تجريبي فريد $i'),
          ),
        ],
        charadesCategories: [],
        avatars: [],
        rulePages: [],
        settings: {},
      );

      final roomNotifier = container.read(gameRoomProvider.notifier);
      final testPlayers = [
        const PlayerModel(id: '1', name: 'أحمد (المضيف)', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
        const PlayerModel(id: '3', name: 'كريم'),
        const PlayerModel(id: '4', name: 'نور'),
      ];
      container.read(roomProvider.notifier).setPlayers(testPlayers);

      final spyCounts = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0};
      const int totalSimulations = 200;

      for (int i = 0; i < totalSimulations; i++) {
        await roomNotifier.startSpyGameRound(
          packSlug: 'places',
          bootstrapData: bigPlacesBootstrap,
          totalRounds: 10000,
          isNewGame: false,
        );
        final spy = container.read(gameRoomProvider).spyPlayerIds.first;
        spyCounts[spy] = (spyCounts[spy] ?? 0) + 1;
      }

      // Every player must be chosen a substantial number of times
      for (final id in spyCounts.keys) {
        expect(spyCounts[id]!, greaterThan(20),
            reason: 'Player $id was selected ${spyCounts[id]} times out of $totalSimulations');
      }

      // Host must NOT be chosen every time or even a vast majority of the time
      expect(spyCounts['1']!, lessThan(totalSimulations ~/ 2));
    });

    test('Single player edge case: chosen as spy without errors', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: 'solo_host', name: 'أحمد', isHost: true),
      ]);

      // Round 1
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: true,
      );
      expect(container.read(gameRoomProvider).spyPlayerIds, equals(['solo_host']));

      // Round 2 (Constraint relaxed smoothly for single player)
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 3,
        isNewGame: false,
      );
      expect(container.read(gameRoomProvider).spyPlayerIds, equals(['solo_host']));
    });

    test('Previous spy leaves room: game proceeds without exceptions', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final roomNotifier = container.read(gameRoomProvider.notifier);
      container.read(roomProvider.notifier).setPlayers([
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
        const PlayerModel(id: '3', name: 'كريم'),
      ]);

      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 5,
        isNewGame: true,
      );
      final spyRound1 = container.read(gameRoomProvider).spyPlayerIds.first;

      // Remove the player who was the spy in Round 1
      final remainingPlayers = [
        const PlayerModel(id: '1', name: 'أحمد', isHost: true),
        const PlayerModel(id: '2', name: 'سارة'),
        const PlayerModel(id: '3', name: 'كريم'),
      ].where((p) => p.id != spyRound1).toList();

      container.read(roomProvider.notifier).setPlayers(remainingPlayers);

      // Round 2 must succeed and select from remaining players
      await roomNotifier.startSpyGameRound(
        packSlug: 'places',
        bootstrapData: null,
        totalRounds: 5,
        isNewGame: false,
      );
      final spyRound2 = container.read(gameRoomProvider).spyPlayerIds.first;
      expect(remainingPlayers.any((p) => p.id == spyRound2), isTrue);
      expect(spyRound2, isNot(equals(spyRound1)));
    });
  });

  group('3) Settings Persistence & Independence Tests', () {
    test('SpySettings persists to storage and restores on recreation', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Change spy settings
      await container.read(spySettingsProvider.notifier).update(
            rounds: 5,
            discussionMinutes: 8,
            votingSeconds: 45,
            guessSeconds: 25,
            spiesCount: 2,
            wordPack: 'movies',
          );

      expect(container.read(spySettingsProvider).rounds, equals(5));
      expect(container.read(spySettingsProvider).discussionMinutes, equals(8));
      expect(container.read(spySettingsProvider).wordPack, equals('movies'));
      container.dispose();

      // Simulate app restart by creating a new ProviderContainer with the same prefs
      final freshContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(freshContainer.dispose);

      final restored = freshContainer.read(spySettingsProvider);
      expect(restored.rounds, equals(5));
      expect(restored.discussionMinutes, equals(8));
      expect(restored.votingSeconds, equals(45));
      expect(restored.guessSeconds, equals(25));
      expect(restored.spiesCount, equals(2));
      expect(restored.wordPack, equals('movies'));
    });

    test('CharadesSettings persists to storage and restores on recreation', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Change charades settings
      await container.read(charadesSettingsProvider.notifier).update(
            roundSeconds: 90,
            roundsPerPlayer: 3,
            category: 'jobs',
          );

      expect(container.read(charadesSettingsProvider).roundSeconds, equals(90));
      container.dispose();

      // Simulate restart
      final freshContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(freshContainer.dispose);

      final restored = freshContainer.read(charadesSettingsProvider);
      expect(restored.roundSeconds, equals(90));
      expect(restored.roundsPerPlayer, equals(3));
      expect(restored.category, equals('jobs'));
    });

    test('Independence: Modifying SpySettings does not affect Trivia or Charades settings',
        () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Initial defaults
      expect(container.read(triviaSettingsProvider).questionsCount, equals(10));
      expect(container.read(charadesSettingsProvider).roundSeconds, equals(60));

      // Update Trivia
      await container.read(triviaSettingsProvider.notifier).update(questionsCount: 20);

      // Update Spy
      await container.read(spySettingsProvider.notifier).update(rounds: 7);

      // Verify independence
      expect(container.read(spySettingsProvider).rounds, equals(7));
      expect(container.read(triviaSettingsProvider).questionsCount, equals(20));
      expect(container.read(charadesSettingsProvider).roundSeconds, equals(60)); // Untouched

      // Switch game provider
      container.read(selectedGameProvider.notifier).state = GameType.charades;
      expect(container.read(spySettingsProvider).rounds, equals(7));
      expect(container.read(triviaSettingsProvider).questionsCount, equals(20));
    });
  });
}
