// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SecondaryButton extends StatelessWidget {
  final String? label;
  final String? title;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;
  final dynamic icon; // Can be IconData or Widget

  const SecondaryButton({
    super.key,
    this.label,
    this.title,
    required this.onPressed,
    this.borderColor = AppColors.textSecondary,
    this.textColor = AppColors.textPrimary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = title ?? label ?? '';

    Widget? iconWidget;
    if (icon != null) {
      if (icon is IconData) {
        iconWidget = Icon(icon as IconData, size: 22, color: textColor);
      } else if (icon is Widget) {
        iconWidget = icon as Widget;
      }
    }

    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null) ...[
              iconWidget,
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
