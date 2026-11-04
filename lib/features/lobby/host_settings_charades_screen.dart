// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/stepper_row.dart';
import '../../data/providers/game_providers.dart';
import '../../data/services/game_content_service.dart';
import 'ai_generation_sheet.dart';

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
                    const SizedBox(height: 14),

                    // إعداد عدد الكلمات في كل دور (المهمة 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.format_list_numbered, color: AppTheme.accentMint, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'عدد الكلمات في كل دور',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ينتهي الدور بانتهاء الكلمات أو انتهاء الوقت (أيهما أسبق)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildWordsLimitPill('5', 5, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 5)),
                              _buildWordsLimitPill('10', 10, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 10)),
                              _buildWordsLimitPill('15', 15, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 15)),
                              _buildWordsLimitPill('20', 20, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 20)),
                              _buildWordsLimitPill('30', 30, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 30)),
                              _buildWordsLimitPill('مفتوح (بلا حد)', 0, settings.wordsPerTurn, () => notifier.update(wordsPerTurn: 0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Categories (أقسام الكلمات المعتمدة القابلة للتمثيل)
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
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildCategoryPill(
                          title: 'أفلام',
                          icon: Icons.movie,
                          code: 'movies',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'movies'),
                        ),
                        _buildCategoryPill(
                          title: 'مسلسلات',
                          icon: Icons.tv,
                          code: 'series',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'series'),
                        ),
                        _buildCategoryPill(
                          title: 'أفعال وحركات',
                          icon: Icons.directions_run,
                          code: 'actions',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'actions'),
                        ),
                        _buildCategoryPill(
                          title: 'مهن',
                          icon: Icons.engineering,
                          code: 'jobs',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'jobs'),
                        ),
                        _buildCategoryPill(
                          title: 'حيوانات',
                          icon: Icons.pets,
                          code: 'animals',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'animals'),
                        ),
                        _buildCategoryPill(
                          title: 'أماكن',
                          icon: Icons.place,
                          code: 'places',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'places'),
                        ),
                        _buildCategoryPill(
                          title: 'أشياء يومية',
                          icon: Icons.category,
                          code: 'things',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'things'),
                        ),
                        _buildCategoryPill(
                          title: 'أمثال شعبية',
                          icon: Icons.format_quote,
                          code: 'proverbs',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'proverbs'),
                        ),
                        _buildCategoryPill(
                          title: 'الكل (مختلط)',
                          icon: Icons.shuffle,
                          code: 'mixed',
                          selectedCode: settings.category,
                          onTap: () => notifier.update(category: 'mixed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // توليد كلمات تمثيل بالذكاء الاصطناعي
                    SecondaryButton(
                      title: 'توليد عبارات تمثيل جديدة بالـ AI',
                      icon: Icons.auto_awesome,
                      borderColor: AppTheme.accentMint,
                      textColor: AppTheme.accentMint,
                      onPressed: () => showAiGenerationSheet(context, gameType: 'charades'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              PrimaryButton(
                title: 'حفظ وارجع للوبي',
                icon: Icons.check_circle,
                accentColor: AppTheme.accentMint,
                onPressed: () {
                  final current = ref.read(charadesSettingsProvider);
                  ref.read(gameRoomProvider.notifier).server?.updateSettings({
                    'charades': current.toJson(),
                    'words_per_turn': current.wordsPerTurn,
                    'round_seconds': current.roundSeconds,
                    'category': current.category,
                  });
                  ref.read(gameContentServiceProvider).autoReplenishCharadesIfNeeded(
                    requiredCount: current.roundsPerPlayer * 4 * (current.wordsPerTurn > 0 ? current.wordsPerTurn : 10),
                    category: current.category,
                  );
                  context.pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordsLimitPill(String title, int value, int selectedValue, VoidCallback onTap) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentMint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                fontSize: 15,
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
