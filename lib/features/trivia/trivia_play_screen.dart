// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/providers/game_providers.dart';
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

    // 1. شاشة اختيار السؤال / التحدي
    if (triviaState.phase == TriviaPhase.questionSelection) {
      return _buildQuestionSelectionView(context, triviaState, notifier);
    }

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
    final displayNum = triviaState.currentQuestionIndex + 1;
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
                      'سؤال $displayNum من $totalQ',
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

              // Reveal Banner
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 20),

              // Options List
              Expanded(
                child: ListView.separated(
                  itemCount: currentQ.options.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
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

              if (isReveal)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white54),
                      icon: const Icon(Icons.flag_outlined, size: 15),
                      label: const Text('إبلاغ عن خطأ في السؤال 🚩', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final api = ref.read(apiClientProvider);
                        await api.reportContent(
                          contentType: 'trivia',
                          contentId: currentQ.id,
                          reason: 'إبلاغ من لاعب أثناء الجولة',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم استلام بلاغك! سنراجع السؤال ونعزله تلقائياً 🙏'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // شاشة اختيار السؤال / التحدي (Problem 2)
  // ==========================================
  Widget _buildQuestionSelectionView(
    BuildContext context,
    TriviaGameState state,
    TriviaGameNotifier notifier,
  ) {
    final remainingIndices = state.remainingQuestionIndices;
    final currentRoundNum = state.playedQuestionIndices.length + 1;
    final total = state.totalQuestions;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.go('/lobby'),
        ),
        title: Text(
          'تحدي الشلة (سؤال $currentRoundNum من $total)',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر السؤال اللي تحب تلعبه:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentSaffron,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اضغط على أي كارت تختاره أو اضغط على عشوائي',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // قائمة الأسئلة المتاحة للاختيار
              Expanded(
                child: remainingIndices.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد أسئلة متبقية',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        itemCount: remainingIndices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final qIndex = remainingIndices[index];
                          final q = state.questions[qIndex];
                          final categoryTitle = _getCategoryTitle(q.categorySlug);

                          return Material(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () {
                                notifier.selectQuestion(qIndex);
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.accentSaffron.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentSaffron.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text('🎯', style: TextStyle(fontSize: 20)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentSaffron.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              categoryTitle,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.accentSaffron,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            q.promptAr,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: AppTheme.accentSaffron,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // زر اختيار عشوائي كخيار إضافي
              PrimaryButton(
                title: 'اختيار عشوائي 🎲',
                icon: Icons.shuffle,
                accentColor: AppTheme.accentSaffron,
                onPressed: () {
                  notifier.selectRandomQuestion();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryTitle(String slug) {
    switch (slug) {
      case 'movies':
        return 'أفلام ومسلسلات';
      case 'sports':
        return 'كورة ورياضة';
      case 'afeehat':
        return 'أفيهات وقفشات';
      case 'history':
        return 'تاريخ ومعالم';
      default:
        return 'منوعات عامة';
    }
  }

  // Reveal banner
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

  // Option card with design states and reliable Material/InkWell gesture handling
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

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
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
              trailingIcon ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
