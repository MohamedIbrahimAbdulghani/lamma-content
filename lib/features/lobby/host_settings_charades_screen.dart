// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/stepper_row.dart';
import '../../data/providers/game_providers.dart';

class HostSettingsCharadesScreen extends ConsumerWidget {
  const HostSettingsCharadesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(charadesSettingsProvider);
    final notifier = ref.read(charadesSettingsProvider.notifier);

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
          'إعدادات مثّل ومتتكلمش',
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
                      title: 'وقت الدور',
                      subtitle: 'الوقت المتاح للشرح بالإشارة',
                      icon: Icons.timer,
                      valueText: '${settings.roundSeconds} ثانية',
                      accentColor: AppTheme.accentMint,
                      onDecrement: () => notifier.update(roundSeconds: settings.roundSeconds - 15),
                      onIncrement: () => notifier.update(roundSeconds: settings.roundSeconds + 15),
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'عدد الأدوار لكل لاعب',
                      subtitle: 'مرات التمثيل المتاحة لكل فرد',
                      icon: Icons.repeat,
                      valueText: '${settings.roundsPerPlayer}',
                      accentColor: AppTheme.accentMint,
                      onDecrement: () => notifier.update(roundsPerPlayer: settings.roundsPerPlayer - 1),
                      onIncrement: () => notifier.update(roundsPerPlayer: settings.roundsPerPlayer + 1),
                    ),
                    const SizedBox(height: 24),

                    // Categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'قسم الكلمات',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'اختر فئة التحدي',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildCategoryPill(
                          title: 'أفلام',
                          icon: Icons.movie,
                          code: 'movies',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'movies'),
                        ),
                        _buildCategoryPill(
                          title: 'مهن',
                          icon: Icons.engineering,
                          code: 'jobs',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'jobs'),
                        ),
                        _buildCategoryPill(
                          title: 'أفعال',
                          icon: Icons.directions_run,
                          code: 'verbs',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'verbs'),
                        ),
                        _buildCategoryPill(
                          title: 'مختلط',
                          icon: Icons.shuffle,
                          code: 'mixed',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'mixed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              PrimaryButton(
                title: 'حفظ وارجع للوبي',
                icon: Icons.check_circle,
                accentColor: AppTheme.accentMint,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String title,
    required IconData icon,
    required String code,
    required String selectedCode,
    required VoidCallback onTap,
  }) {
    final isSelected = code == selectedCode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentMint : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF101428) : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF101428) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
