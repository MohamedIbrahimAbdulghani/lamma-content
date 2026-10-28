// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/row_card.dart';
import '../../data/providers/game_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(localStorageProvider);
    final playerName = storage.getPlayerName();
    final currentSelectedGame = ref.watch(selectedGame);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Top Bar Section: Greeting, Settings & Help Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'أهلاً يا $playerName',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings, color: AppColors.textSecondary, size: 24),
                        tooltip: 'الإعدادات',
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => context.push('/howto'),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '؟',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Three Stacked Game Cards
              _buildGameCard(
                game: GameType.spy,
                emoji: '🕵️',
                title: 'مين الجاسوس',
                subtitle: 'دوّر على الجاسوس بينكم',
                accentColor: AppColors.spyAccent,
                isSelected: currentSelectedGame == GameType.spy,
              ),
              const SizedBox(height: AppDimensions.rowGap),
              _buildGameCard(
                game: GameType.trivia,
                emoji: '🎯',
                title: 'تحدي الشلة',
                subtitle: 'أسئلة وأفيهات وكورة',
                accentColor: AppColors.triviaAccent,
                isSelected: currentSelectedGame == GameType.trivia,
              ),
              const SizedBox(height: AppDimensions.rowGap),
              _buildGameCard(
                game: GameType.charades,
                emoji: '🎭',
                title: 'مثّل ومتتكلمش',
                subtitle: 'مثّل الكلمة من غير كلام',
                accentColor: AppColors.charadesAccent,
                isSelected: currentSelectedGame == GameType.charades,
              ),
              const Spacer(),
              // Bottom Actions: Create & Join Room
              PrimaryButton(
                label: 'أنشئ غرفة',
                backgroundColor: AppColors.generalAccent,
                onPressed: () => context.push('/room/create?mode=${currentSelectedGame.name}'),
              ),
              const SizedBox(height: AppDimensions.rowGap),
              SecondaryButton(
                label: 'ادخل غرفة',
                onPressed: () => context.push('/room/join'),
              ),
              const SizedBox(height: 16),
              // Bottom Brand Signature
              const Center(
                child: Text(
                  'Mohamed Ibrahim',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required GameType game,
    required String emoji,
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool isSelected,
  }) {
    return RowCard(
      onTap: () {
        ref.read(selectedGame.notifier).state = game;
        ref.read(gameRoomProvider.notifier).setSelectedGame(game);
      },
      borderColor: isSelected ? accentColor : Colors.transparent,
      borderWidth: 2,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? accentColor : AppColors.card,
              border: Border.all(
                color: isSelected ? accentColor : AppColors.textSecondary.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: AppColors.textOnAccent)
                : null,
          ),
        ],
      ),
    );
  }
}
