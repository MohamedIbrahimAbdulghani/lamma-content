// Lamma Party Game - Spy Anti-Repetition Tests
// Tests 10,000 rounds simulation, 3% consecutive repetition exception,
// host distribution fairness, 1-player/2-player edges, and room state persistence.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/data/models/player_model.dart';
import 'package:lamma_party_game_app/data/providers/game_providers.dart';
import 'package:lamma_party_game_app/features/spy/domain/spy_selector.dart';

void main() {
  group('SpySelector Domain & Fairness Tests', () {
    test('10,000 rounds simulation: consecutive spy repetition is ~3% and host is not biased', () {
      final players = [
        const PlayerModel(id: 'host', name: 'المضيف (أحمد)', emoji: '👑'),
        const PlayerModel(id: 'player_2', name: 'سارة', emoji: '🦊'),
        const PlayerModel(id: 'player_3', name: 'كريم', emoji: '🐻'),
        const PlayerModel(id: 'player_4', name: 'نور', emoji: '🐼'),
      ];

      const int totalRounds = 10000;
      int consecutiveRepeats = 0;
      final Map<String, int> spyCounts = {
        'host': 0,
        'player_2': 0,
        'player_3': 0,
        'player_4': 0,
      };

      List<String> previousSpies = [];

      for (int i = 0; i < totalRounds; i++) {
        final chosenSpies = SpySelector.selectSpyIds(
          activePlayers: players,
          previousSpyIds: previousSpies,
          neededSpies: 1,
        );

        expect(chosenSpies.length, 1);
        final currentSpy = chosenSpies.first;

        if (previousSpies.isNotEmpty && previousSpies.contains(currentSpy)) {
          consecutiveRepeats++;
        }

        spyCounts[currentSpy] = (spyCounts[currentSpy] ?? 0) + 1;
        previousSpies = chosenSpies;
      }

      final double repeatPercentage = (consecutiveRepeats / (totalRounds - 1)) * 100;
      // النسبة المتوقعة نظرياً هي 3% (بين 2.0% و 4.2% بفاصل ثقة واسع جداً لـ 10,000 محاولة)
      expect(
        repeatPercentage,
        inInclusiveRange(2.0, 4.2),
        reason: 'Consecutive spy repetition rate should be very close to 3% (was ${repeatPercentage.toStringAsFixed(2)}%)',
      );

      // التأكد من عدالة اختيار المضيف مقارنة بالباقين (لا يوجد تحيز للمضيف)
      // مع 4 لاعبين، النسبة المتوقعة لكل لاعب هي ~25% (2500 مرة +/- 300)
      for (final entry in spyCounts.entries) {
        final share = entry.value / totalRounds;
        expect(
          share,
          inInclusiveRange(0.21, 0.29),
          reason: 'Player ${entry.key} had share ${(share * 100).toStringAsFixed(1)}%, expected ~25%',
        );
      }
    });

    test('Single player room: always picked as spy without crashing or exceptions', () {
      final singlePlayer = [
        const PlayerModel(id: 'solo', name: 'وحيد', emoji: '👤'),
      ];

      for (int i = 0; i < 50; i++) {
        final chosen = SpySelector.selectSpyIds(
          activePlayers: singlePlayer,
          previousSpyIds: ['solo'],
          neededSpies: 1,
        );
        expect(chosen, ['solo']);
      }
    });

    test('Two players room: alternates roles ~97% of the time based on 3% exception', () {
      final twoPlayers = [
        const PlayerModel(id: 'p1', name: 'لاعب 1', emoji: '🦁'),
        const PlayerModel(id: 'p2', name: 'لاعب 2', emoji: '🐯'),
      ];

      const int rounds = 2000;
      int alternates = 0;
      List<String> prev = ['p1'];

      for (int i = 0; i < rounds; i++) {
        final chosen = SpySelector.selectSpyIds(
          activePlayers: twoPlayers,
          previousSpyIds: prev,
          neededSpies: 1,
        );
        expect(chosen.length, 1);
        if (chosen.first != prev.first) {
          alternates++;
        }
        prev = chosen;
      }

      final double alternateRate = (alternates / rounds) * 100;
      // المتوقع ~97% تبادل (بين 95% و 98.8%)
      expect(
        alternateRate,
        inInclusiveRange(95.0, 98.8),
        reason: 'In 2-player room, spies should alternate ~97% of rounds (was ${alternateRate.toStringAsFixed(2)}%)',
      );
    });

    test('Previous spy left the room: remaining players are all eligible without bias', () {
      final activePlayers = [
        const PlayerModel(id: 'p2', name: 'سارة', emoji: '🦊'),
        const PlayerModel(id: 'p3', name: 'كريم', emoji: '🐻'),
      ];

      // الجاسوس السابق كان p1 ولكنه غادر الغرفة
      final previousSpies = ['p1_left'];

      final chosen = SpySelector.selectSpyIds(
        activePlayers: activePlayers,
        previousSpyIds: previousSpies,
        neededSpies: 1,
      );

      expect(chosen.length, 1);
      expect(['p2', 'p3'].contains(chosen.first), isTrue);
    });
  });

  group('Room State & Reset Persistence Tests', () {
    test('resetSpyRound keeps previousSpyIds so next game round remembers who was spy', () {
      final notifier = RoomNotifier();
      notifier.state = ActiveRoomState(
        roomCode: 'TEST1',
        isHost: true,
        currentRound: 3,
        totalRounds: 3,
        spyPlayerIds: ['spy_player_99'],
        previousSpyIds: ['spy_player_99'],
        players: [
          const PlayerModel(id: 'spy_player_99', name: 'سالم', role: 'spy'),
          const PlayerModel(id: 'player_2', name: 'هدى', role: 'citizen'),
          const PlayerModel(id: 'player_3', name: 'عمر', role: 'citizen'),
        ],
      );

      // استدعاء إعادة تعيين الجولة (العودة للوبي أو العب تاني)
      notifier.resetSpyRound();

      expect(notifier.state.currentPhase, 'lobby');
      expect(notifier.state.currentRound, 1);
      // التأكد أن جاسوس الجولة السابقة لم يضع أبداً بل استمر
      expect(notifier.state.previousSpyIds, contains('spy_player_99'));
    });
  });
}
