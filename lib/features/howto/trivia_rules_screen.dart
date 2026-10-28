// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class TriviaRulesScreen extends StatelessWidget {
  const TriviaRulesScreen({super.key});

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
          'قواعد تحدي الشلة',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentSaffron,
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
                color: AppTheme.accentSaffron,
                child: const Text(
                  'أسئلة ثقافة عامة وإفيهات مصرية وكورة والكل بيجاوب في نفس الوقت على موبايله.',
                  style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),

              _buildCard(
                title: 'إزاي بتتلعب',
                color: AppTheme.accentSaffron,
                child: Column(
                  children: const [
                    _StepItem(number: '١', text: 'كل لاعب بيظهرله السؤال في نفس اللحظة.'),
                    SizedBox(height: 8),
                    _StepItem(number: '٢', text: 'اختار الإجابة الصح قبل ما الوقت يخلص.'),
                    SizedBox(height: 8),
                    _StepItem(number: '٣', text: 'الأسرع بياخد نقاط أعلى في الترتيب!'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildCard(
                title: 'النقاط',
                color: AppTheme.accentSaffron,
                child: Column(
                  children: [
                    _buildScoreRow('إجابة صحيحة', '+100 نقطة', AppTheme.accentSaffron),
                    const SizedBox(height: 8),
                    _buildScoreRow('بونص سرعة', 'حتى +50 نقطة', AppTheme.accentSaffron),
                    const SizedBox(height: 8),
                    _buildScoreRow('إجابة خاطئة', '0 نقطة', AppTheme.textSecondary),
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

class _StepItem extends StatelessWidget {
  final String number;
  final String text;

  const _StepItem({required this.number, required this.text});

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
              color: AppTheme.accentSaffron,
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
