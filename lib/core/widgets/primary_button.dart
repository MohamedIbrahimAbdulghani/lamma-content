// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String? label;
  final String? title;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? accentColor;
  final Color textColor;
  final dynamic icon; // Can be IconData or Widget
  final bool isLoading;

  const PrimaryButton({
    super.key,
    this.label,
    this.title,
    required this.onPressed,
    this.backgroundColor,
    this.accentColor,
    this.textColor = AppColors.textOnAccent,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = title ?? label ?? '';
    final bgColor = accentColor ?? backgroundColor ?? AppColors.generalAccent;

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
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
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
                      fontSize: 18.0,
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
