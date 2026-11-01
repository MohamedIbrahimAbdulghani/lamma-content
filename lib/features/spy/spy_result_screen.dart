// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/player_model.dart';
import '../../data/providers/game_providers.dart';

class SpyResultScreen extends ConsumerWidget {
  const SpyResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(gameRoomProvider);

    // هنجيب بيانات الجاسوس الحقيقية من الـ state
    final spyIds = roomState.spyPlayerIds;
    final allPlayers = roomState.players.isNotEmpty
        ? roomState.players
        : [
            PlayerModel(id: '1', name: 'أحمد', avatar: '🦁', score: 0),
            PlayerModel(id: '2', name: 'سارة', avatar: '🦊', score: 0),
          ];

    // بنجيب بيانات الجاسوس
    final spyPlayers = allPlayers.where((p) => spyIds.contains(p.id)).toList();
    final spyPlayer = spyPlayers.isNotEmpty ? spyPlayers.first : null;

    // نتيجة اللعبة
    final outcome = roomState.spyOutcome;
    final secretWord = roomState.secretWord;
    final guessedWord = roomState.spyGuessedWord;
    final isLastRound = roomState.currentRound >= roomState.totalRounds;

    // بنحدد الـ title والـ subtitle بناءً على النتيجة
    String resultTitle;
    String resultSubtitle;
    Color accentColor;
    IconData resultIcon;

    if (outcome == SpyGameOutcome.citizensWin) {
      resultTitle = 'المواطنين كسبوا! 🎉';
      resultSubtitle = 'كشفوا الجاسوس وهو مخمنش الكلمة صح';
      accentColor = AppTheme.accentMint;
      resultIcon = Icons.verified_user;
    } else if (outcome == SpyGameOutcome.spyWinsGuess) {
      resultTitle = 'الجاسوس كسب! 🕵️';
      resultSubtitle = 'اتكشف بس خمن الكلمة صح!';
      accentColor = AppTheme.accentCoral;
      resultIcon = Icons.visibility;
    } else if (outcome == SpyGameOutcome.spyWinsHidden) {
      resultTitle = 'الجاسوس كسب! 🕵️';
      resultSubtitle = 'مكتشفوش! صوتوا على حد غلط';
      accentColor = AppTheme.accentCoral;
      resultIcon = Icons.visibility;
    } else {
      resultTitle = 'النتيجة';
      resultSubtitle = '';
      accentColor = AppTheme.accentSaffron;
      resultIcon = Icons.emoji_events;
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.go('/lobby'),
        ),
        title: const Text(
          'النتيجة',
          style: TextStyle(
            fontSize: 22,
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
                    const SizedBox(height: 8),

                    // عداد الجولة الحالية
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentCoral.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'جولة ${roomState.currentRound} من ${roomState.totalRounds}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCoral,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // أيقونة النتيجة
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(resultIcon, color: accentColor, size: 48),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // عنوان النتيجة (مين كسب)
                    Text(
                      resultTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    if (resultSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        resultSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // بيانات الجاسوس
                    if (spyPlayer != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentCoral.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'الجاسوس كان',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              spyPlayer.avatar,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              spyPlayer.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // الكلمة السرية
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الكلمة السرية:',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            secretWord,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentMint,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // تخمين الجاسوس لو موجود
                    if (guessedWord != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'تخمين الجاسوس:',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  guessedWord,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: (roomState.spyGuessedCorrectly == true)
                                        ? AppTheme.accentMint
                                        : AppTheme.accentCoral,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  (roomState.spyGuessedCorrectly == true)
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: (roomState.spyGuessedCorrectly == true)
                                      ? AppTheme.accentMint
                                      : AppTheme.accentCoral,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // قائمة اللاعبين
                    ...allPlayers.map((p) {
                      final isSpy = spyIds.contains(p.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: isSpy
                                ? Border.all(
                                    color: AppTheme.accentCoral.withValues(alpha: 0.4),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(p.avatar, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 12),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSpy
                                      ? AppTheme.accentCoral.withValues(alpha: 0.2)
                                      : AppTheme.accentMint.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isSpy ? '🕵️ جاسوس' : '✅ مواطن',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSpy ? AppTheme.accentCoral : AppTheme.accentMint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!isLastRound) ...[
                PrimaryButton(
                  title: 'إعادة الجولة (${roomState.currentRound + 1} من ${roomState.totalRounds}) 🔄',
                  accentColor: AppTheme.accentCoral,
                  icon: Icons.replay,
                  onPressed: () async {
                    final settings = ref.read(spySettingsProvider);
                    final bootstrap = ref.read(bootstrapProvider);
                    await ref.read(gameRoomProvider.notifier).startSpyGameRound(
                      packSlug: settings.wordPack,
                      bootstrapData: bootstrap.data,
                      totalRounds: settings.rounds,
                      isNewGame: false,
                    );
                    if (context.mounted) {
                      context.go('/spy/role');
                    }
                  },
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  title: 'رجوع للقائمة 🚪',
                  icon: Icons.exit_to_app,
                  onPressed: () {
                    context.go('/lobby');
                  },
                ),
              ] else ...[
                PrimaryButton(
                  title: 'الترتيب النهائي 🏆',
                  accentColor: AppTheme.accentSaffron,
                  icon: Icons.emoji_events,
                  onPressed: () {
                    context.go('/feedback/final-results');
                  },
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  title: 'العب تاني 🔄',
                  icon: Icons.replay,
                  onPressed: () async {
                    final settings = ref.read(spySettingsProvider);
                    final bootstrap = ref.read(bootstrapProvider);
                    await ref.read(gameRoomProvider.notifier).startSpyGameRound(
                      packSlug: settings.wordPack,
                      bootstrapData: bootstrap.data,
                      totalRounds: settings.rounds,
                      isNewGame: true,
                    );
                    if (context.mounted) {
                      context.go('/spy/role');
                    }
                  },
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  title: 'إنهاء اللعبة 🚪',
                  icon: Icons.exit_to_app,
                  onPressed: () {
                    ref.read(gameRoomProvider.notifier).resetSpyRound();
                    context.go('/lobby');
                  },
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
