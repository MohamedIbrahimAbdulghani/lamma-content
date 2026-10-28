// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/stepper_row.dart';
import '../../data/providers/game_providers.dart';

class HostSettingsTriviaScreen extends ConsumerWidget {
  const HostSettingsTriviaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(triviaSettingsProvider);
    final notifier = ref.read(triviaSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'إعدادات تحدي الشلة',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    StepperRow(
                      title: 'عدد الأسئلة',
                      icon: Icons.quiz,
                      valueText: '${settings.questionsCount}',
                      accentColor: AppTheme.accentSaffron,
                      onDecrement: () => notifier.update(questionsCount: settings.questionsCount - 1),
                      onIncrement: () => notifier.update(questionsCount: settings.questionsCount + 1),
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'وقت السؤال',
                      icon: Icons.timer,
                      valueText: '${settings.timePerQuestion} ثانية',
                      accentColor: AppTheme.accentSaffron,
                      onDecrement: () => notifier.update(timePerQuestion: settings.timePerQuestion - 5),
                      onIncrement: () => notifier.update(timePerQuestion: settings.timePerQuestion + 5),
                    ),
                    const SizedBox(height: 24),

                    // Difficulty
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الصعوبة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildDiffPill('الكل', 'all', settings.difficulty, (val) => notifier.update(difficulty: val)),
                        const SizedBox(width: 8),
                        _buildDiffPill('سهل', 'easy', settings.difficulty, (val) => notifier.update(difficulty: val)),
                        const SizedBox(width: 8),
                        _buildDiffPill('متوسط', 'medium', settings.difficulty, (val) => notifier.update(difficulty: val)),
                        const SizedBox(width: 8),
                        _buildDiffPill('حراق', 'hard', settings.difficulty, (val) => notifier.update(difficulty: val)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Categories
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأقسام',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCategoryChip('أفلام ومسلسلات', 'movies', settings.categories, notifier.toggleCategory),
                        _buildCategoryChip('كورة مصرية', 'sports', settings.categories, notifier.toggleCategory),
                        _buildCategoryChip('إفيهات وقفشات', 'afeehat', settings.categories, notifier.toggleCategory),
                        _buildCategoryChip('تاريخ وجغرافيا', 'history', settings.categories, notifier.toggleCategory),
                        _buildCategoryChip('عامة', 'general', settings.categories, notifier.toggleCategory),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              PrimaryButton(
                title: 'حفظ وارجع للوبي',
                icon: Icons.check,
                accentColor: AppTheme.accentSaffron,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffPill(String title, String value, String currentValue, Function(String) onSelect) {
    final isSelected = value == currentValue;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentSaffron : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF101428) : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String title, String id, List<String> selectedCategories, Function(String) onToggle) {
    final isSelected = selectedCategories.contains(id);
    return InkWell(
      onTap: () => onToggle(id),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentSaffron : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: const Color(0xFF4F4534)),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF101428) : Colors.white,
          ),
        ),
      ),
    );
  }
}
