// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'presentation/controllers/trivia_controller.dart';
import 'presentation/controllers/trivia_state.dart';

class TriviaPlayScreen extends ConsumerWidget {
  const TriviaPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triviaState = ref.watch(triviaGameProvider);
    final notifier = ref.read(triviaGameProvider.notifier);

    // Listen to phase transitions to auto-advance
    ref.listen<TriviaGameState>(triviaGameProvider, (previous, next) {
      if (next.phase == TriviaPhase.leaderboard) {
        context.go('/trivia/leaderboard');
      } else if (next.phase == TriviaPhase.completed) {
        context.go('/feedback/final-results');
      }
    });

    final currentQ = triviaState.currentQuestion;
    if (currentQ == null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentSaffron),
        ),
      );
    }

    final totalQ = triviaState.totalQuestions;
    final currentNumber = triviaState.currentQuestionIndex + 1;
    final isReveal = triviaState.phase == TriviaPhase.reveal;
    final isCorrect = triviaState.answerResult == TriviaAnswerResult.correct;
    final isWrong = triviaState.answerResult == TriviaAnswerResult.wrong;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Question badge and circular timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'سؤال $currentNumber من $totalQ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cardBg,
                      border: Border.all(
                        color: isReveal
                            ? (isCorrect ? AppTheme.accentMint : AppTheme.accentCoral)
                            : AppTheme.accentSaffron,
                        width: 2.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${triviaState.secondsLeft}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isReveal
                            ? (isCorrect ? AppTheme.accentMint : AppTheme.accentCoral)
                            : AppTheme.accentSaffron,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reveal Banner (Screen 18 / 19)
              if (isReveal && isCorrect)
                _buildCorrectBanner(points: triviaState.lastEarnedPoints)
              else if (isReveal && isWrong)
                _buildWrongBanner()
              else
                const SizedBox(height: 12),

              const SizedBox(height: 16),

              // Question Prompt Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentQ.promptAr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 24),

              // Options List
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentQ.options.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final optionText = currentQ.options[index];
                    return _buildOptionCard(
                      index: index,
                      text: optionText,
                      correctIndex: currentQ.correctIndex,
                      selectedIndex: triviaState.selectedOptionIndex,
                      isReveal: isReveal,
                      isLocked: triviaState.isAnswerLocked,
                      onTap: () => notifier.submitAnswer(index),
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

  // Screen 18 Reveal banner
  Widget _buildCorrectBanner({required int points}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accentMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF101428),
                ),
                child: const Icon(Icons.check, color: AppTheme.accentMint, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'إجابة صح! 🎉',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101428),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF101428),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$points نقطة',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentMint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Screen 19 Reveal banner
  Widget _buildWrongBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.5), width: 1.5),
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
                  color: AppTheme.accentCoral.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.close, color: AppTheme.accentCoral, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'إجابة غلط ❌',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCoral,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF252B50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '+0 نقطة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCoral,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Option card with design 17, 18, 19 states
  Widget _buildOptionCard({
    required int index,
    required String text,
    required int correctIndex,
    required int? selectedIndex,
    required bool isReveal,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    Color bgColor = AppTheme.cardBg;
    Color borderColor = const Color(0xFF30385E);
    Color textColor = Colors.white;
    Widget? trailingIcon;

    if (isReveal) {
      final isThisCorrect = (index == correctIndex);
      final isThisSelected = (selectedIndex == index);

      if (isThisCorrect) {
        if (isThisSelected) {
          // Screen 18 chosen correct: full mint card
          bgColor = AppTheme.accentMint;
          borderColor = AppTheme.accentMint;
          textColor = const Color(0xFF101428);
          trailingIcon = Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF101428),
            ),
            child: const Icon(Icons.check, color: AppTheme.accentMint, size: 20),
          );
        } else {
          // Screen 19 correct answer highlight: cardBg with mint border & mint check
          bgColor = AppTheme.cardBg;
          borderColor = AppTheme.accentMint;
          textColor = AppTheme.accentMint;
          trailingIcon = Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentMint.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.check, color: AppTheme.accentMint, size: 20),
          );
        }
      } else if (isThisSelected) {
        // Screen 19 chosen wrong answer: coral card with close icon
        bgColor = AppTheme.accentCoral;
        borderColor = AppTheme.accentCoral;
        textColor = const Color(0xFF101428);
        trailingIcon = Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF101428).withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.close, color: Color(0xFF101428), size: 20),
          );
      }
    }

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            ?trailingIcon,
          ],
        ),
      ),
    );
  }
}
