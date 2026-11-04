// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/game_back_handler.dart';
import 'controllers/charades_controller.dart';

class CharadesRoundSummaryScreen extends ConsumerWidget {
  const CharadesRoundSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charadesState = ref.watch(charadesGameProvider);
    final history = charadesState.roundHistory;
    final correctCount = charadesState.correctCountInRound;
    final passedCount = charadesState.passedCountInRound;
    final attemptedCount = charadesState.wordsAttemptedInRound;
    final currentPlayerName = charadesState.currentPlayer?.name ?? 'اللاعب';

    // بنشوف مين اللاعب اللي بعده أو هل دي آخر جولة
    final isLastPlayer = charadesState.currentPlayerIndex >= charadesState.players.length - 1;
    final isLastRound = charadesState.currentRound >= charadesState.totalRounds;
    final willCompleteGame = isLastPlayer && isLastRound;

    return GameBackScope(
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const GameBackCircularButton(),
                    Text(
                      'خلص دور $currentPlayerName!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                '$correctCount كلمات صح 🎉',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentMint,
                ),
              ),
              const SizedBox(height: 16),

              // بطاقات إحصائيات الدور (معروضة، عرفوها، تخطي)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill(
                      label: 'المعروضة',
                      value: charadesState.isWordsLimitEnabled
                          ? '$attemptedCount من ${charadesState.wordsPerTurn}'
                          : '$attemptedCount',
                      color: Colors.white,
                    ),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildStatPill(
                      label: 'عرفوها',
                      value: '$correctCount',
                      color: AppTheme.accentMint,
                    ),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildStatPill(
                      label: 'تخطي',
                      value: '$passedCount',
                      color: AppTheme.accentCoral,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // قائمة الكلمات اللي اتلعبت في الدور ده
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          'الوقت خلص بدون تخمين أي كلمة',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final isCorrect = item['correct'] as bool? ?? false;
                          final word = item['word'] as String? ?? '';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCorrect
                                    ? AppTheme.accentMint.withValues(alpha: 0.3)
                                    : AppTheme.accentCoral.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  word,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                isCorrect
                                    ? const Text(
                                        '✔',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentMint,
                                        ),
                                      )
                                    : const Text(
                                        'تخطّي',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentCoral,
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              PrimaryButton(
                title: willCompleteGame ? 'النتائج النهائية (مين كسب) 🏆' : 'الدور اللي بعده',
                accentColor: willCompleteGame ? AppTheme.accentSaffron : AppTheme.accentMint,
                icon: willCompleteGame ? Icons.emoji_events : Icons.arrow_forward,
                onPressed: () {
                  final isDone = ref.read(charadesGameProvider.notifier).advanceToNextTurn();
                  if (isDone) {
                    context.go('/feedback/final-results');
                  } else {
                    context.go('/charades/handoff');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
