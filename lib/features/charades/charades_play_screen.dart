// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_back_handler.dart';
import 'controllers/charades_controller.dart';
import 'controllers/charades_state.dart';

enum FlashState { none, correct, pass }

class CharadesPlayScreen extends ConsumerStatefulWidget {
  const CharadesPlayScreen({super.key});

  @override
  ConsumerState<CharadesPlayScreen> createState() => _CharadesPlayScreenState();
}

class _CharadesPlayScreenState extends ConsumerState<CharadesPlayScreen> {
  FlashState _flashState = FlashState.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final current = ref.read(charadesGameProvider);
      if (current.words.isEmpty) {
        await ref.read(charadesGameProvider.notifier).initGame();
      }
      if (mounted) {
        ref.read(charadesGameProvider.notifier).startRound();
      }
    });
  }

  void _onCorrect() {
    if (_flashState != FlashState.none) return;
    setState(() {
      _flashState = FlashState.correct;
    });
    ref.read(charadesGameProvider.notifier).markCorrect();
    _resetFlash();
  }

  void _onPass() {
    if (_flashState != FlashState.none) return;
    setState(() {
      _flashState = FlashState.pass;
    });
    ref.read(charadesGameProvider.notifier).markPass();
    _resetFlash();
  }

  void _resetFlash() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _flashState = FlashState.none;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final charadesState = ref.watch(charadesGameProvider);

    // لما الوقت يخلص أو يكتمل عدد الكلمات المحدد، بننقل على ملخص الجولة
    ref.listen<CharadesGameState>(charadesGameProvider, (prev, next) {
      if (next.isRoundActive == false && prev?.isRoundActive == true) {
        context.go('/charades/summary');
      }
    });

    if (charadesState.isLoading || charadesState.words.isEmpty) {
      return GameBackScope(
        child: Scaffold(
          backgroundColor: AppTheme.bg,
          body: const SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentMint),
                  SizedBox(height: 24),
                  Text(
                    'جاري تجهيز الكلمات...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final secondsLeft = charadesState.secondsLeft;
    final minutes = (secondsLeft ~/ 60).toString();
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    final currentWord = charadesState.currentWord;
    final correctCount = charadesState.correctCountInRound;
    final passedCount = charadesState.passedCountInRound;
    final playerName = charadesState.currentPlayer?.name ?? '';

    return GameBackScope(
      child: Scaffold(
        backgroundColor: _flashState == FlashState.correct
            ? AppTheme.accentMint
            : (_flashState == FlashState.pass ? AppTheme.accentCoral : AppTheme.bg),
        body: SafeArea(
          child: _flashState != FlashState.none
              ? _buildFlashContent()
              : _buildPlayContent(charadesState, minutes, seconds, currentWord, correctCount, passedCount, playerName),
        ),
      ),
    );
  }

  Widget _buildFlashContent() {
    final isCorrect = _flashState == FlashState.correct;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.fast_forward,
            size: 96,
            color: const Color(0xFF101428),
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'عرفوها! 🎉 (+1)' : 'تخطّي! ❌',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101428),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayContent(
    CharadesGameState charadesState,
    String minutes,
    String seconds,
    String word,
    int correctCount,
    int passedCount,
    String playerName,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. زر الرجوع ولوحة نقاط حية ظاهرة طول اللعب (Live Scoreboard)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: GameBackCircularButton(),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildLiveScoreBoard(charadesState)),
            ],
          ),
          const SizedBox(height: 12),

          // 2. تايمر الجولة وإحصائيات الدور
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check, color: AppTheme.accentMint, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'عرفوها: $correctCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentMint,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentMint,
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.close, color: AppTheme.accentCoral, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'تخطي: $passedCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCoral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // 3. عرض الكلمة
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentMint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'دور: $playerName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentMint,
                        ),
                      ),
                    ),
                    if (charadesState.isWordsLimitEnabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25293E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentMint.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'كلمة ${charadesState.currentWordNumberInTurn} من ${charadesState.wordsPerTurn}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 4. زراير عرفوها (+1) وتخطي
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Color(0xFF101428), size: 24),
                    label: const Text(
                      'عرفوها ✅ (+1)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101428),
                      ),
                    ),
                    onPressed: _onCorrect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentMint,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                    label: const Text(
                      'تخطي ❌',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _onPass,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accentCoral, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// لوحة النقاط الحية تظهر جميع الفرق/اللاعبين مع تمييز الفريق الحالي
  Widget _buildLiveScoreBoard(CharadesGameState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentMint.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'لوحة النقاط 🏆',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                'جولة ${state.currentRound} من ${state.totalRounds}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.players.map((p) {
                final isCurrent = (p.id == state.currentPlayer?.id);
                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.accentMint.withValues(alpha: 0.2)
                        : const Color(0xFF25293E),
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent
                        ? Border.all(color: AppTheme.accentMint, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? AppTheme.accentMint : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppTheme.accentMint : Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${p.score}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? const Color(0xFF101428) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
