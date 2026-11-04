// Lamma - Game Back Confirmation Dialog
// Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../constants/game_strings.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

class GameBackDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmTitle;
  final Color confirmColor;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GameBackDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmTitle,
    required this.confirmColor,
    required this.confirmIcon,
    required this.onConfirm,
    required this.onCancel,
  });

  // حارس ذري لمنع فتح أكثر من حوار عند الضغطات السريعة المتتالية (Rapid Double-Tap Protection)
  static bool _isDialogOpen = false;

  /// عرض حوار المضيف: الرجوع للوبي وإلغاء الجولة
  static Future<bool> showHostReturnDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) async {
    if (_isDialogOpen) return false;
    _isDialogOpen = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameBackDialog(
        title: GameStrings.hostReturnDialogTitle,
        message: GameStrings.hostReturnDialogMessage,
        confirmTitle: GameStrings.hostReturnConfirmButton,
        confirmColor: AppTheme.accentCoral,
        confirmIcon: Icons.cancel_outlined,
        onConfirm: () {
          Navigator.of(ctx).pop(true);
          onConfirm();
        },
        onCancel: () {
          Navigator.of(ctx).pop(false);
        },
      ),
    );

    _isDialogOpen = false;
    return result ?? false;
  }

  /// عرض حوار اللاعب غير المضيف: تأكيد مغادرة الغرفة
  static Future<bool> showPlayerLeaveDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) async {
    if (_isDialogOpen) return false;
    _isDialogOpen = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameBackDialog(
        title: GameStrings.playerLeaveDialogTitle,
        message: GameStrings.playerLeaveDialogMessage,
        confirmTitle: GameStrings.playerLeaveConfirmButton,
        confirmColor: AppTheme.accentCoral,
        confirmIcon: Icons.exit_to_app,
        onConfirm: () {
          Navigator.of(ctx).pop(true);
          onConfirm();
        },
        onCancel: () {
          Navigator.of(ctx).pop(false);
        },
      ),
    );

    _isDialogOpen = false;
    return result ?? false;
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
              color: confirmColor.withValues(alpha: 0.5),
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
                  color: confirmColor.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Icon(confirmIcon, color: confirmColor, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B7C3),
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                title: confirmTitle,
                icon: confirmIcon,
                accentColor: confirmColor,
                onPressed: onConfirm,
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                title: GameStrings.cancelDialogButton,
                icon: Icons.close,
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
