// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CountdownRing extends StatelessWidget {
  final int? remainingSeconds;
  final int? totalSeconds;
  final double? progress;
  final double size;
  final Color? color;
  final Color activeColor;
  final Widget? child;

  const CountdownRing({
    super.key,
    this.remainingSeconds,
    this.totalSeconds,
    this.progress,
    this.size = 100,
    this.color,
    this.activeColor = AppColors.generalAccent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final computedProgress = progress ??
        ((totalSeconds != null && totalSeconds! > 0 && remainingSeconds != null)
            ? (remainingSeconds! / totalSeconds!).clamp(0.0, 1.0)
            : 0.0);

    final displayColor = color ??
        ((remainingSeconds != null && remainingSeconds! <= 5)
            ? AppColors.spyAccent
            : activeColor);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: computedProgress,
              strokeWidth: 6,
              backgroundColor: const Color(0xFF1B2140),
              valueColor: AlwaysStoppedAnimation<Color>(displayColor),
            ),
          ),
          child ??
              Text(
                '${remainingSeconds ?? 0}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: displayColor,
                ),
              ),
        ],
      ),
    );
  }
}
