// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';
import 'controllers/charades_controller.dart';

class CharadesSpectatorScreen extends ConsumerStatefulWidget {
  const CharadesSpectatorScreen({super.key});

  @override
  ConsumerState<CharadesSpectatorScreen> createState() => _CharadesSpectatorScreenState();
}

class _CharadesSpectatorScreenState extends ConsumerState<CharadesSpectatorScreen> {
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    final roomState = ref.read(gameRoomProvider);
    _secondsLeft = roomState.timerSeconds > 0 ? roomState.timerSeconds : 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameRoomProvider);
    final activePlayer = roomState.players.isNotEmpty ? roomState.players.first.name : 'أحمد';
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 6),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 4),
            PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 3),
            PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 2),
          ];

    final minutes = (_secondsLeft ~/ 60).toString();
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final charadesState = ref.watch(charadesGameProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                '$activePlayer بيمثّل دلوقتي',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (charadesState.isWordsLimitEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentMint.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'كلمة ${charadesState.currentWordNumberInTurn} من ${charadesState.wordsPerTurn}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentMint,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Timer Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentMint,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Players live scores
              Expanded(
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = players[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(p.avatar, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${p.score} كلمات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: index == 0 ? AppTheme.accentMint : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
