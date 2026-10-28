// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HowToMenuScreen extends StatelessWidget {
  const HowToMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'طريقة اللعب',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              _buildMenuItem(
                emoji: '📱',
                title: 'إزاي تستخدم التطبيق',
                onTap: () => context.push('/how-to/app'),
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                emoji: '🕵️',
                title: 'مين الجاسوس',
                onTap: () => context.push('/how-to/spy'),
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                emoji: '🎯',
                title: 'تحدي الشلة',
                onTap: () => context.push('/how-to/trivia'),
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                emoji: '🎭',
                title: 'مثّل ومتتكلمش',
                onTap: () => context.push('/how-to/charades'),
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                emoji: '⚠️',
                title: 'قواعد الغش والمخالفات',
                onTap: () => context.push('/how-to/anti-cheat'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String emoji,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF252C54),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
