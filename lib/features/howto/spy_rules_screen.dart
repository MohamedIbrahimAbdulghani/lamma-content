// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SpyRulesScreen extends StatelessWidget {
  const SpyRulesScreen({super.key});

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
          'قواعد مين الجاسوس',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentCoral,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListView(
            children: [
              // الفكرة
              _buildCard(
                title: 'الفكرة',
                color: AppTheme.accentCoral,
                child: const Text(
                  'كلكم عارفين الكلمة السرية ما عدا الجاسوس.',
                  style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),

              // إزاي بتتلعب
              _buildCard(
                title: 'إزاي بتتلعب',
                color: AppTheme.accentCoral,
                child: Column(
                  children: const [
                    _RuleStep(number: '١', text: 'كل لاعب يشوف دوره بالسر ويسلم الهاتف.'),
                    SizedBox(height: 8),
                    _RuleStep(number: '٢', text: 'اسألوا بعض أسئلة ذكية تكشف الجاسوس بحذر.'),
                    SizedBox(height: 8),
                    _RuleStep(number: '٣', text: 'صوّتوا على المشتبه فيه بعد نهاية الوقت.'),
                    SizedBox(height: 8),
                    _RuleStep(number: '٤', text: 'لو اتكشف الجاسوس، يحاول تخمين الكلمة للفوز.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // النقاط
              _buildCard(
                title: 'النقاط',
                color: AppTheme.accentCoral,
                child: Column(
                  children: [
                    _buildScoreRow('الجاسوس ما اتكشفش', '+3', AppTheme.accentCoral),
                    const SizedBox(height: 8),
                    _buildScoreRow('اتكشف وخمّن صح', '+2', AppTheme.accentCoral),
                    const SizedBox(height: 8),
                    _buildScoreRow('اتكشف وخمّن غلط', '+2 لكل مواطن صوّت صح', AppTheme.accentCoral),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // نصيحة
              _buildCard(
                title: 'نصيحة',
                color: AppTheme.accentCoral,
                child: const Text(
                  'اسأل أسئلة غامضة وذكية علشان الجاسوس ميعرفش الكلمة!',
                  style: TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
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
          Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
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

class _RuleStep extends StatelessWidget {
  final String number;
  final String text;

  const _RuleStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF25293E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppTheme.accentCoral,
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
              style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
