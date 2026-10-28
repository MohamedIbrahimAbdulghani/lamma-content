// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class CharadesRoundSummaryScreen extends ConsumerWidget {
  const CharadesRoundSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = [
      {'word': 'الفرح', 'correct': true},
      {'word': 'طيارة', 'correct': true},
      {'word': 'كورة', 'correct': false},
      {'word': 'بحر', 'correct': true},
      {'word': 'مدرسة', 'correct': true},
    ];

    final correctCount = words.where((w) => w['correct'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'خلص الوقت',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$correctCount كلمات صح',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentMint,
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView.separated(
                  itemCount: words.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = words[index];
                    final isCorrect = item['correct'] as bool;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['word'] as String,
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
                title: 'الدور اللي بعده',
                accentColor: AppTheme.accentMint,
                onPressed: () {
                  context.go('/charades/handoff');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
