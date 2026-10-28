// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';

class FinalResultsScreen extends ConsumerWidget {
  const FinalResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 1240),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 980),
            PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 720),
            PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 540),
            PlayerModel(id: '5', name: 'عمر', avatar: '🐯', score: 410),
          ];

    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;
    final rest = sorted.length > 3 ? sorted.sublist(3) : <PlayerModel>[];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'الفايز',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 12),
                    // Podium Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 2nd Place (Right side in RTL)
                        if (second != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: second,
                              rank: 2,
                              title: 'فضة',
                              height: 110,
                              rankColor: AppTheme.textSecondary,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),

                        // 1st Place (Center, tallest)
                        if (first != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: first,
                              rank: 1,
                              title: 'البطل',
                              height: 150,
                              rankColor: AppTheme.accentSaffron,
                              isChampion: true,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),

                        // 3rd Place (Left side in RTL)
                        if (third != null)
                          Expanded(
                            child: _buildPodiumStep(
                              player: third,
                              rank: 3,
                              title: 'برونز',
                              height: 90,
                              rankColor: const Color(0xFFD3C5AD),
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Rest of players
                    ...rest.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(p.avatar, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 10),
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${p.score} نقطة',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),

              PrimaryButton(
                title: 'الرئيسية',
                icon: Icons.home,
                accentColor: AppTheme.accentSaffron,
                onPressed: () {
                  context.go('/home');
                },
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Mohamed Ibrahim',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumStep({
    required PlayerModel player,
    required int rank,
    required String title,
    required double height,
    required Color rankColor,
    bool isChampion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isChampion)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 22),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: isChampion ? 32 : 26,
              backgroundColor: isChampion ? AppTheme.accentSaffron : AppTheme.cardBg,
              child: Text(
                player.avatar,
                style: TextStyle(fontSize: isChampion ? 32 : 26),
              ),
            ),
            Positioned(
              bottom: -8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101428),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '${player.score} نقطة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: rankColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: isChampion ? const Color(0xFF25293E) : AppTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
        ),
      ],
    );
  }
}
