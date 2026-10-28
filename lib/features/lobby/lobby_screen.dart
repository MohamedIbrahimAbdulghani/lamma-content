// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';
import '../trivia/presentation/controllers/trivia_controller.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final isHost = roomState.isHost;
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', isHost: true),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊'),
            PlayerModel(id: '3', name: 'كريم', avatar: '🐻'),
            PlayerModel(id: '4', name: 'نور', avatar: '🐼'),
            PlayerModel(id: '5', name: 'عمر', avatar: '🐯'),
            PlayerModel(id: '6', name: 'ياسمين', avatar: '🐨'),
          ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () {
            ref.read(gameRoomProvider.notifier).leaveRoom();
            context.go('/home');
          },
        ),
        title: const Text(
          'اللوبي',
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
                    // Top Bar: Room Code & Copy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tag, color: AppTheme.accentSaffron, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'كود الغرفة: ${roomState.roomCode}',
                                style: const TextStyle(
                                  color: AppTheme.accentSaffron,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: roomState.roomCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ الكود!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.content_copy, color: AppTheme.textSecondary, size: 18),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${players.length} لاعبين',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Players Section
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الصحبة في اللوبي',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Grid of 2 columns
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF25293E),
                                    child: Text(
                                      p.avatar,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                  if (p.isHost)
                                    Positioned(
                                      top: -6,
                                      left: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.accentSaffron,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text('👑', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Game Selection Section
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر نوع اللعبة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildGamePill(
                          title: 'مين الجاسوس',
                          type: GameType.spy,
                          selectedType: roomState.selectedGame,
                          isHost: isHost,
                          onTap: () {
                            ref.read(selectedGame.notifier).state = GameType.spy;
                            ref.read(gameRoomProvider.notifier).setSelectedGame(GameType.spy);
                          },
                        ),
                        _buildGamePill(
                          title: 'تحدي الشلة',
                          type: GameType.trivia,
                          selectedType: roomState.selectedGame,
                          isHost: isHost,
                          onTap: () {
                            ref.read(selectedGame.notifier).state = GameType.trivia;
                            ref.read(gameRoomProvider.notifier).setSelectedGame(GameType.trivia);
                          },
                        ),
                        _buildGamePill(
                          title: 'مثّل ومتتكلمش',
                          type: GameType.charades,
                          selectedType: roomState.selectedGame,
                          isHost: isHost,
                          onTap: () {
                            ref.read(selectedGame.notifier).state = GameType.charades;
                            ref.read(gameRoomProvider.notifier).setSelectedGame(GameType.charades);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              const SizedBox(height: 12),
              if (isHost) ...[
                SecondaryButton(
                  title: 'إعدادات اللعبة',
                  icon: Icons.tune,
                  onPressed: () {
                    switch (roomState.selectedGame) {
                      case GameType.spy:
                        context.push('/host-settings/spy');
                        break;
                      case GameType.trivia:
                        context.push('/host-settings/trivia');
                        break;
                      case GameType.charades:
                        context.push('/host-settings/charades');
                        break;
                    }
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  title: 'ابدأ اللعبة',
                  icon: Icons.play_arrow,
                  accentColor: _accentColorForGame(roomState.selectedGame),
                  onPressed: () {
                    ref.read(gameRoomProvider.notifier).startGame();
                    switch (roomState.selectedGame) {
                      case GameType.spy:
                        context.go('/spy/role');
                        break;
                      case GameType.trivia:
                        ref.read(triviaGameProvider.notifier).restartGame();
                        context.go('/trivia/question');
                        break;
                      case GameType.charades:
                        context.go('/charades/handoff');
                        break;
                    }
                  },
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'في انتظار صاحب الغرفة يبدأ اللعبة...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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

  Widget _buildGamePill({
    required String title,
    required GameType type,
    required GameType selectedType,
    required bool isHost,
    required VoidCallback onTap,
  }) {
    final isSelected = type == selectedType;
    final color = _accentColorForGame(type);

    return InkWell(
      onTap: isHost ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: isSelected ? null : Border.all(color: const Color(0xFF4F4534)),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF101428) : Colors.white,
          ),
        ),
      ),
    );
  }

  Color _accentColorForGame(GameType game) {
    switch (game) {
      case GameType.spy:
        return AppTheme.accentCoral;
      case GameType.trivia:
        return AppTheme.accentSaffron;
      case GameType.charades:
        return AppTheme.accentMint;
    }
  }
}
