// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';

class SpyResultScreen extends ConsumerWidget {
  const SpyResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final players = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 150),
            PlayerModel(id: '4', name: 'نور', avatar: '🐼', score: 120),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 40),
          ];

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
          'النتيجة',
          style: TextStyle(
            fontSize: 22,
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
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppTheme.cardBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('🦊', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الجاسوس كان سارة 🦊',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Players scores
                    ...players.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 12),
              PrimaryButton(
                title: 'الجولة اللي بعدها',
                accentColor: AppTheme.accentCoral,
                onPressed: () {
                  context.go('/lobby');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
