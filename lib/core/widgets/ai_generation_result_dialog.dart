// Lamma - by Mohamed Ibrahim

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../data/storage/local_storage.dart';

/// نوع نتيجة عملية توليد الذكاء الاصطناعي
enum AiResultType {
  success,
  partial,
  failure,
}

/// عرض نافذة منبثقة (Dialog) في منتصف الشاشة بنتائج التوليد بتصميم التطبيق
Future<void> showAiGenerationResultDialog(
  BuildContext context, {
  required AiResultType type,
  required String message,
  String? title,
  String? details,
  String? debugInfo,
  VoidCallback? onRetry,
  LocalStorage? storage,
}) async {
  if (!context.mounted) return;

  // حارس لمنع تداخل أو تراكم أكثر من نافذة منبثقة في نفس الوقت
  if (AiGenerationResultDialog.isShowing) return;
  AiGenerationResultDialog.isShowing = true;

  try {
    // احترام إعدادات الأصوات والاهتزاز المخزنة (النجاح فقط)
    final soundEnabled = storage?.getSoundEnabled() ?? true;
    final vibrationEnabled = storage?.getVibrationEnabled() ?? true;

    if (type == AiResultType.success) {
      if (vibrationEnabled) {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      }
      if (soundEnabled) {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AiGenerationResultDialog(
          type: type,
          title: title,
          message: message,
          details: details,
          debugInfo: debugInfo,
          onRetry: onRetry,
        ),
      ),
    );
  } finally {
    AiGenerationResultDialog.isShowing = false;
  }
}

class AiGenerationResultDialog extends StatefulWidget {
  static bool isShowing = false;

  final AiResultType type;
  final String? title;
  final String message;
  final String? details;
  final String? debugInfo;
  final VoidCallback? onRetry;

  const AiGenerationResultDialog({
    super.key,
    required this.type,
    this.title,
    required this.message,
    this.details,
    this.debugInfo,
    this.onRetry,
  });

  @override
  State<AiGenerationResultDialog> createState() => _AiGenerationResultDialogState();
}

class _AiGenerationResultDialogState extends State<AiGenerationResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkProgress;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );

    _checkProgress = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeInOutCubic),
    );

    _animController.forward();

    // الإغلاق التلقائي بعد 2.5 ثانية لحالات النجاح والنجاح الجزئي
    if (widget.type == AiResultType.success || widget.type == AiResultType.partial) {
      _autoCloseTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getColorForType(widget.type);
    final defaultTitle = _getDefaultTitleForType(widget.type);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الأيقونة المتحركة في المنتصف
            Center(
              child: _buildAnimatedIcon(themeColor),
            ),
            const SizedBox(height: 18),

            // العنوان
            Text(
              widget.title ?? defaultTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // الرسالة التوضيحية
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),

            // تفاصيل إضافية (مثل توزيع الألعاب)
            if (widget.details != null && widget.details!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  widget.details!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            // معلومات الديباج (في وضع kDebugMode فقط)
            if (kDebugMode && widget.debugInfo != null && widget.debugInfo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.debugInfo!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.amberAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 22),

            // الأزرار التفاعلية
            if (widget.type == AiResultType.failure)
              Row(
                children: [
                  if (widget.onRetry != null) ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCoral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          widget.onRetry!();
                        },
                        child: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text('إغلاق', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: const Color(0xFF101428),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text(
                  'تمام 👍',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(Color color) {
    if (widget.type == AiResultType.success) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          child: AnimatedBuilder(
            animation: _checkProgress,
            builder: (context, child) {
              return CustomPaint(
                painter: _AnimatedCheckPainter(
                  progress: _checkProgress.value,
                  color: color,
                ),
              );
            },
          ),
        ),
      );
    } else if (widget.type == AiResultType.partial) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          child: Icon(
            Icons.priority_high_rounded,
            color: color,
            size: 40,
          ),
        ),
      );
    } else {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          child: Icon(
            Icons.close_rounded,
            color: color,
            size: 40,
          ),
        ),
      );
    }
  }

  Color _getColorForType(AiResultType type) {
    switch (type) {
      case AiResultType.success:
        return AppTheme.accentMint;
      case AiResultType.partial:
        return AppTheme.accentSaffron;
      case AiResultType.failure:
        return AppTheme.accentCoral;
    }
  }

  String _getDefaultTitleForType(AiResultType type) {
    switch (type) {
      case AiResultType.success:
        return 'تم التحديث بنجاح';
      case AiResultType.partial:
        return 'تحديث جزئي';
      case AiResultType.failure:
        return 'تعذّر التحديث';
    }
  }
}

/// رسام علامة الصح المتحركة (Path Extraction Animation)
class _AnimatedCheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AnimatedCheckPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // نقاط علامة الصح النسبية داخل الدائرة
    final start = Offset(size.width * 0.28, size.height * 0.52);
    final mid = Offset(size.width * 0.44, size.height * 0.68);
    final end = Offset(size.width * 0.72, size.height * 0.36);

    path.moveTo(start.dx, start.dy);
    path.lineTo(mid.dx, mid.dy);
    path.lineTo(end.dx, end.dy);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(0.0, (acc, m) => acc + m.length);
    final targetLength = totalLength * progress.clamp(0.0, 1.0);

    double currentLength = 0.0;
    for (final metric in metrics) {
      if (currentLength >= targetLength) break;
      final remaining = targetLength - currentLength;
      final extractLength = remaining.clamp(0.0, metric.length);
      final segment = metric.extractPath(0.0, extractLength);
      canvas.drawPath(segment, paint);
      currentLength += metric.length;
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
