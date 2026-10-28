// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class CharadesRulesScreen extends StatelessWidget {
  const CharadesRulesScreen({super.key});

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
          'قواعد مثّل ومتتكلمش',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentMint,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListView(
            children: [
              _buildCard(
                title: 'الفكرة',
                color: AppTheme.accentMint,
                child: const Text(
                  'مثّل الكلمة اللي على الشاشة من غير ما تتكلم وصحابك يخمنوا!',
                  style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),

              _buildCard(
                title: 'إزاي بتتلعب',
                color: AppTheme.accentMint,
                child: Column(
                  children: const [
                    _StepItemMint(number: '١', text: 'حط الموبايل على جبهتك بحيث صحابك يشوفوا الشاشة.'),
                    SizedBox(height: 8),
                    _StepItemMint(number: '٢', text: 'لو خمنوا صح: نزّل الموبايل لقدام = صح.'),
                    SizedBox(height: 8),
                    _StepItemMint(number: '٣', text: 'لو صعبة: ارفع الموبايل لفوق = تخطي.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildCard(
                title: 'النقاط',
                color: AppTheme.accentMint,
                child: Column(
                  children: [
                    _buildScoreRow('كل كلمة صحيحة', '+1 نقطة', AppTheme.accentMint),
                    const SizedBox(height: 8),
                    _buildScoreRow('التخطي', '0 نقطة', AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String points, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF25293E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.white)),
          Text(points, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _StepItemMint extends StatelessWidget {
  final String number;
  final String text;

  const _StepItemMint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF25293E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppTheme.accentMint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101428),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
