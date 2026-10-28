// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class StrikeWarningScreen extends StatelessWidget {
  final String playerName;
  final int strikeCount;

  const StrikeWarningScreen({
    super.key,
    this.playerName = 'عمر',
    this.strikeCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentCoral,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.warning,
                        color: Color(0xFF101428),
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '⚠️ $playerName خرج من اللعبة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Strike Dots (1 to 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isStrike = index < strikeCount;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isStrike ? AppTheme.accentCoral : AppTheme.cardBg,
                          border: isStrike ? null : Border.all(color: const Color(0xFF34384E)),
                        ),
                        alignment: Alignment.center,
                        child: isStrike
                            ? const Icon(Icons.close, size: 18, color: Color(0xFF101428))
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'مخالفة $strikeCount من 3',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              PrimaryButton(
                title: 'تمام',
                accentColor: AppTheme.accentCoral,
                onPressed: () {
                  context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
