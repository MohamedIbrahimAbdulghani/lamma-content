// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PillItem<T> {
  final T value;
  final String label;
  final String? emoji;

  const PillItem({
    required this.value,
    required this.label,
    this.emoji,
  });
}

class PillSelector<T> extends StatelessWidget {
  final List<PillItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Color activeColor;

  const PillSelector({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.activeColor = AppColors.generalAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = item.value == selectedValue;
        return InkWell(
          onTap: () => onSelected(item.value),
          borderRadius: BorderRadius.circular(9999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : AppColors.card,
              borderRadius: BorderRadius.circular(9999),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.emoji != null) ...[
                  Text(item.emoji!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.textOnAccent : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
