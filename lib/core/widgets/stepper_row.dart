// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'row_card.dart';

class StepperRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? value;
  final String? valueDisplay;
  final String? valueText;
  final int? min;
  final int? max;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final IconData? icon;
  final Color? accentColor;

  const StepperRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueDisplay,
    this.valueText,
    this.min,
    this.max,
    this.onChanged,
    this.onIncrement,
    this.onDecrement,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = valueText ?? valueDisplay ?? '${value ?? 0}';
    final activeAccent = accentColor ?? AppTheme.accentSaffron;

    final canDecrement = onDecrement != null || (value != null && min != null && value! > min!);
    final canIncrement = onIncrement != null || (value != null && max != null && value! < max!);

    return RowCard(
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF25293E),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: activeAccent, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(
                icon: Icons.remove,
                enabled: canDecrement,
                onPressed: () {
                  if (onDecrement != null) {
                    onDecrement!();
                  } else if (value != null && onChanged != null) {
                    onChanged!(value! - 1);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: activeAccent,
                  ),
                ),
              ),
              _buildButton(
                icon: Icons.add,
                enabled: canIncrement,
                onPressed: () {
                  if (onIncrement != null) {
                    onIncrement!();
                  } else if (value != null && onChanged != null) {
                    onChanged!(value! + 1);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF25293E) : const Color(0xFF1E2438),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
