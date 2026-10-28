// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/providers/game_providers.dart';

class CharadesHandoffScreen extends ConsumerWidget {
  const CharadesHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);
    final activePlayer = roomState.players.isNotEmpty ? roomState.players.first.name : 'أحمد';
    final activeAvatar = roomState.players.isNotEmpty ? roomState.players.first.avatar : '🦁';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentMint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        activeAvatar,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'الدور على $activePlayer',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سلم الموبايل له علشان يبدأ الدور',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                title: 'أنا جاهز',
                icon: Icons.play_arrow,
                accentColor: AppTheme.accentMint,
                onPressed: () {
                  context.push('/charades/instructions');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
