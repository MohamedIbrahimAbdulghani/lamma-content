// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AntiCheatRulesScreen extends StatelessWidget {
  const AntiCheatRulesScreen({super.key});

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
          'قواعد الغش',
          style: TextStyle(
            fontSize: 22,
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
              // Strike Dots Indicator Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(filled: true),
                    Container(width: 24, height: 2, color: const Color(0xFF303449)),
                    _buildDot(filled: false),
                    Container(width: 24, height: 2, color: const Color(0xFF303449)),
                    _buildDot(filled: false),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rule 1
              _buildRuleCard(
                icon: Icons.tab,
                iconColor: AppTheme.accentSaffron,
                text: 'اخرج من التطبيق = مخالفة',
              ),
              const SizedBox(height: 12),

              // Rule 2
              _buildRuleCard(
                icon: Icons.person_off,
                iconColor: AppTheme.accentCoral,
                text: '3 مخالفات = طرد',
              ),
              const SizedBox(height: 12),

              // Rule 3
              _buildRuleCard(
                icon: Icons.no_photography,
                iconColor: AppTheme.accentMint,
                text: 'لقطات الشاشة ممنوعة',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot({required bool filled}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: filled ? AppTheme.accentCoral : const Color(0xFF303449),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.close,
        size: 18,
        color: filled ? const Color(0xFF101428) : AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildRuleCard({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF25293E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
