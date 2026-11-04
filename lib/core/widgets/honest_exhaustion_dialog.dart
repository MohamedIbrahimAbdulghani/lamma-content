// Lamma - Honest Exhaustion Dialog
// تظهر فقط عند فشل التوليد بعد استنفاد كل المحاولات لبيان السبب الحقيقي وإعطاء المضيف خيار إعادة المحاولة أو إعادة استخدام ما شاهده

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

class HonestExhaustionDialog extends StatelessWidget {
  final String gameTitle;
  final String reason;
  final VoidCallback? onRetry;
  final VoidCallback onReuseSeen;
  final VoidCallback onTryLater;

  const HonestExhaustionDialog({
    super.key,
    required this.gameTitle,
    required this.reason,
    this.onRetry,
    required this.onReuseSeen,
    required this.onTryLater,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameTitle,
    required String reason,
    VoidCallback? onRetry,
    required VoidCallback onReuseSeen,
    required VoidCallback onTryLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HonestExhaustionDialog(
        gameTitle: gameTitle,
        reason: reason,
        onRetry: onRetry,
        onReuseSeen: onReuseSeen,
        onTryLater: onTryLater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.accentCoral.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentCoral.withValues(alpha: 0.15),
                ),
                child: const Center(
                  child: Text('⚠️', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعذر تجهيز محتوى جديد في $gameTitle',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                reason.isNotEmpty
                    ? reason
                    : 'تعذر الاتصال بخدمة الذكاء الاصطناعي لتجهيز أسئلة جديدة غير مشاهَدة.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B7C3),
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 24),
              if (onRetry != null) ...[
                PrimaryButton(
                  title: 'إعادة المحاولة 🔄',
                  icon: Icons.refresh,
                  accentColor: AppTheme.accentSaffron,
                  onPressed: onRetry!,
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  title: 'إعادة استخدام ما تم مشاهدته ♻️',
                  icon: Icons.history,
                  onPressed: onReuseSeen,
                ),
              ] else ...[
                PrimaryButton(
                  title: 'إعادة استخدام ما شاهدته ♻️',
                  icon: Icons.refresh,
                  accentColor: AppTheme.accentSaffron,
                  onPressed: onReuseSeen,
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: onTryLater,
                child: const Text(
                  'خروج للوبي 🚪',
                  style: TextStyle(
                    color: Color(0xFF8E95A5),
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
