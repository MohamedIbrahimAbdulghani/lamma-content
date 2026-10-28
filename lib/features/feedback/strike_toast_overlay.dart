// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StrikeToastOverlay extends StatelessWidget {
  final String playerName;
  final int strikeCount;
  final VoidCallback? onDismiss;

  const StrikeToastOverlay({
    super.key,
    required this.playerName,
    required this.strikeCount,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2140),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentCoral, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.accentCoral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Color(0xFF101428),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠️ $playerName خرج من التطبيق (مخالفة $strikeCount من 3)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
