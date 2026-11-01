// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';
import '../charades/controllers/charades_controller.dart';
import '../trivia/presentation/controllers/trivia_controller.dart';

class FinalResultsScreen extends ConsumerWidget {
  const FinalResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final triviaState = ref.watch(triviaGameProvider);

    final rawPlayers = (roomState.selectedGame == GameType.trivia && triviaState.players.isNotEmpty)
        ? triviaState.players
        : (roomState.players.isNotEmpty ? roomState.players : const <PlayerModel>[]);

    final players = rawPlayers.isNotEmpty
        ? rawPlayers
        : [
            const PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 1240),
            const PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 980),
            const PlayerModel(id: '3', name: 'كريم', avatar: '🐻', score: 720),
            const PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 540),
            const PlayerModel(id: '5', name: 'عمر', avatar: '🐯', score: 410),
          ];

    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;
    final rest = sorted.length > 3 ? sorted.sublist(3) : <PlayerModel>[];

    final rank2 = (second != null && first != null && second.score == first.score) ? 1 : 2;
    final rank3 = (third != null && second != null && third.score == second.score)
        ? rank2
        : ((third != null && first != null && third.score == first.score) ? 1 : 3);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.go('/lobby'),
        ),
        title: const Text(
          'الترتيب النهائي 🏆',
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
                              rank: rank2,
                              title: 'فضة 🥈',
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
                              title: 'البطل 🥇',
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
                              rank: rank3,
                              title: 'برونز 🥉',
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
                    ...rest.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.avatar,
                                    style: const TextStyle(fontSize: 22),
                                  ),
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
                      ),
                    ),
                  ],
                ),
              ),

              // زراير النهاية: العب تاني ورجوع للقائمة
              PrimaryButton(
                title: 'العب تاني 🔄',
                icon: Icons.replay,
                accentColor: AppTheme.accentSaffron,
                onPressed: () async {
                  if (roomState.selectedGame == GameType.charades) {
                    await ref.read(charadesGameProvider.notifier).restartGame();
                    if (context.mounted) {
                      context.go('/charades/handoff');
                    }
                  } else if (roomState.selectedGame == GameType.trivia) {
                    await ref.read(triviaGameProvider.notifier).restartGame();
                    if (context.mounted) {
                      context.go('/trivia/question');
                    }
                  } else {
                    final settings = ref.read(spySettingsProvider);
                    final bootstrap = ref.read(bootstrapProvider);
                    await ref
                        .read(gameRoomProvider.notifier)
                        .startSpyGameRound(
                          packSlug: settings.wordPack,
                          bootstrapData: bootstrap.data,
                          totalRounds: settings.rounds,
                          isNewGame: true,
                        );
                    if (context.mounted) {
                      context.go('/spy/role');
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                title: 'رجوع للقائمة 🚪',
                icon: Icons.exit_to_app,
                onPressed: () {
                  context.go('/lobby');
                },
              ),
              const SizedBox(height: 8),
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
              backgroundColor: isChampion
                  ? AppTheme.accentSaffron
                  : AppTheme.cardBg,
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
