// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/game_back_handler.dart';
import 'controllers/charades_controller.dart';

class CharadesHandoffScreen extends ConsumerWidget {
  const CharadesHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charadesState = ref.watch(charadesGameProvider);
    final activePlayer = charadesState.currentPlayer?.name ?? 'أحمد';
    final activeAvatar = charadesState.currentPlayer?.avatar ?? '🦁';
    final roundNumber = charadesState.currentRound;
    final totalRounds = charadesState.totalRounds;

    return GameBackScope(
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر الرجوع ورقم الجولة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const GameBackCircularButton(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'الجولة $roundNumber من $totalRounds',
                        style: const TextStyle(
                          color: AppTheme.accentMint,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),

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
    ),
    );
  }
}
