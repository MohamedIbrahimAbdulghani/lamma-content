// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import 'presentation/controllers/trivia_controller.dart';
import 'presentation/controllers/trivia_state.dart';

class TriviaLeaderboardScreen extends ConsumerWidget {
  const TriviaLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triviaState = ref.watch(triviaGameProvider);
    final notifier = ref.read(triviaGameProvider.notifier);

    // Listen to auto-advancing from leaderboard
    ref.listen<TriviaGameState>(triviaGameProvider, (previous, next) {
      if (next.phase == TriviaPhase.question) {
        context.go('/trivia/question');
      } else if (next.phase == TriviaPhase.completed) {
        context.go('/feedback/final-results');
      }
    });

    // Players are strictly sorted descending by cumulative score
    final sortedPlayers = triviaState.sortedPlayers;
    final isLastQ = triviaState.isLastQuestion;

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
          'الترتيب',
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
                child: ListView.separated(
                  itemCount: sortedPlayers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = sortedPlayers[index];
                    final rank = index + 1;
                    final isFirst = (rank == 1);

                    return Container(
                      height: 76,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: isFirst
                            ? Border.all(
                                color: AppTheme.accentSaffron.withValues(alpha: 0.6),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFirst
                                      ? AppTheme.accentSaffron
                                      : const Color(0xFF303449),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isFirst
                                        ? const Color(0xFF101428)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                            '${p.score} نقطة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isFirst ? AppTheme.accentSaffron : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Button also displays 3s countdown and allows manual skip
              PrimaryButton(
                title: isLastQ
                    ? 'النتائج النهائية (${triviaState.leaderboardSecondsLeft}ث)'
                    : 'السؤال التالي (${triviaState.leaderboardSecondsLeft}ث)',
                icon: isLastQ ? Icons.emoji_events : Icons.play_arrow,
                accentColor: AppTheme.accentSaffron,
                onPressed: () {
                  notifier.advanceFromLeaderboard();
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
