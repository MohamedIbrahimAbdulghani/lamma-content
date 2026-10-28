// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/stepper_row.dart';
import '../../data/providers/game_providers.dart';

class HostSettingsSpyScreen extends ConsumerWidget {
  const HostSettingsSpyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spySettingsProvider);
    final notifier = ref.read(spySettingsProvider.notifier);

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
          'إعدادات مين الجاسوس',
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
                    // Section 1: خيارات الجولة
                    _buildSectionHeader(
                      title: 'خيارات الجولة',
                      icon: Icons.tune,
                      color: AppTheme.accentCoral,
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'عدد الجولات',
                      icon: Icons.repeat,
                      valueText: '${settings.rounds}',
                      accentColor: AppTheme.accentCoral,
                      onDecrement: () => notifier.update(rounds: settings.rounds - 1),
                      onIncrement: () => notifier.update(rounds: settings.rounds + 1),
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'وقت النقاش',
                      icon: Icons.forum,
                      valueText: '${settings.discussionMinutes} دقايق',
                      accentColor: AppTheme.accentCoral,
                      onDecrement: () => notifier.update(discussionMinutes: settings.discussionMinutes - 1),
                      onIncrement: () => notifier.update(discussionMinutes: settings.discussionMinutes + 1),
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'وقت التصويت',
                      icon: Icons.how_to_vote,
                      valueText: '${settings.votingSeconds} ثانية',
                      accentColor: AppTheme.accentCoral,
                      onDecrement: () => notifier.update(votingSeconds: settings.votingSeconds - 5),
                      onIncrement: () => notifier.update(votingSeconds: settings.votingSeconds + 5),
                    ),
                    const SizedBox(height: 12),
                    StepperRow(
                      title: 'وقت تخمين الجاسوس',
                      icon: Icons.psychology,
                      valueText: '${settings.guessSeconds} ثانية',
                      accentColor: AppTheme.accentCoral,
                      onDecrement: () => notifier.update(guessSeconds: settings.guessSeconds - 5),
                      onIncrement: () => notifier.update(guessSeconds: settings.guessSeconds + 5),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: عدد الجواسيس
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(
                          title: 'عدد الجواسيس',
                          icon: Icons.theater_comedy,
                          color: AppTheme.accentCoral,
                        ),
                        const Text(
                          'حسب عدد اللاعبين',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpyPill(
                            title: 'تلقائي',
                            isSelected: settings.spiesCount == 0,
                            onTap: () => notifier.update(spiesCount: 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSpyPill(
                            title: '1',
                            isSelected: settings.spiesCount == 1,
                            onTap: () => notifier.update(spiesCount: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSpyPill(
                            title: '2',
                            isSelected: settings.spiesCount == 2,
                            onTap: () => notifier.update(spiesCount: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section 3: حزمة الكلمات
                    _buildSectionHeader(
                      title: 'حزمة الكلمات',
                      icon: Icons.category,
                      color: AppTheme.accentCoral,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildWordPackPill(
                          title: 'أماكن',
                          code: 'places',
                          selectedCode: settings.wordPack,
                          onTap: () => notifier.update(wordPack: 'places'),
                        ),
                        _buildWordPackPill(
                          title: 'أفلام',
                          code: 'movies',
                          selectedCode: settings.wordPack,
                          onTap: () => notifier.update(wordPack: 'movies'),
                        ),
                        _buildWordPackPill(
                          title: 'أكلات',
                          code: 'food',
                          selectedCode: settings.wordPack,
                          onTap: () => notifier.update(wordPack: 'food'),
                        ),
                        _buildWordPackPill(
                          title: 'مختلط',
                          code: 'mixed',
                          selectedCode: settings.wordPack,
                          onTap: () => notifier.update(wordPack: 'mixed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              PrimaryButton(
                title: 'حفظ وارجع للوبي',
                icon: Icons.check,
                accentColor: AppTheme.accentCoral,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSpyPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCoral : AppTheme.cardBg,
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
    );
  }

  Widget _buildWordPackPill({
    required String title,
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
          color: isSelected ? AppTheme.accentCoral : AppTheme.cardBg,
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
    );
  }
}
