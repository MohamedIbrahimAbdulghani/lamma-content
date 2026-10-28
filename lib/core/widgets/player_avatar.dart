// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  final String emoji;
  final String name;
  final bool isHost;
  final int strikes;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  const PlayerAvatar({
    super.key,
    required this.emoji,
    required this.name,
    this.isHost = false,
    this.strikes = 0,
    this.size = 56,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.generalAccent : AppColors.card,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.generalAccent
                        : (strikes > 0 ? AppColors.spyAccent : AppColors.textSecondary.withValues(alpha: 0.3)),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: size * 0.48),
                ),
              ),
              if (isHost)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.generalAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 14,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                ),
              if (strikes > 0)
                Positioned(
                  bottom: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.spyAccent,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '❌$strikes',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 20,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: isHost ? FontWeight.w700 : FontWeight.w500,
                color: isHost ? AppColors.generalAccent : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
