// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/providers/game_providers.dart';

class SpyRoleScreen extends ConsumerStatefulWidget {
  const SpyRoleScreen({super.key});

  @override
  ConsumerState<SpyRoleScreen> createState() => _SpyRoleScreenState();
}

class _SpyRoleScreenState extends ConsumerState<SpyRoleScreen> {
  bool _isRevealed = false;
  double _holdProgress = 0.0;
  Timer? _progressTimer;

  void _startHold() {
    _holdProgress = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _holdProgress += 0.1;
        if (_holdProgress >= 1.0) {
          _holdProgress = 1.0;
          _isRevealed = true;
          _progressTimer?.cancel();
        }
      });
    });
  }

  void _cancelHold() {
    _progressTimer?.cancel();
    if (!_isRevealed) {
      setState(() {
        _holdProgress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameRoomProvider);
    final myId = roomState.myPlayerId;
    final isSpy = roomState.spyPlayerIds.contains(myId);
    final secretWord = roomState.secretWord.isNotEmpty ? roomState.secretWord : 'خان الخليلي';
    final category = roomState.secretCategory.isNotEmpty ? roomState.secretCategory : 'أماكن';

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
          'كارت الدور السري',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTapDown: (_) => _startHold(),
                    onTapUp: (_) => _cancelHold(),
                    onTapCancel: () => _cancelHold(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 460),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isRevealed
                              ? (isSpy ? AppTheme.accentCoral : AppTheme.accentMint)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _isRevealed
                          ? (isSpy ? _buildSpyContent() : _buildCitizenContent(secretWord, category))
                          : _buildHiddenContent(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isRevealed)
                PrimaryButton(
                  title: 'جاهز للنقاش',
                  icon: Icons.forum,
                  accentColor: AppTheme.accentCoral,
                  onPressed: () => context.go('/spy/discussion'),
                )
              else
                const Text(
                  'المس الكارت باستمرار عشان تكشف دورك السري',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🕵️', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        const Text(
          'اضغط واستمر للكشف',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ماحدش يشوف شاشتك',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 140,
            height: 6,
            child: LinearProgressIndicator(
              value: _holdProgress,
              backgroundColor: const Color(0xFF303449),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCoral),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenContent(String word, String pack) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.accentMint.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.verified_user, color: AppTheme.accentMint, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentMint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'أنت مواطن شريف',
            style: TextStyle(
              color: AppTheme.accentMint,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'المكان السري هو:',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          word,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'الحزمة: $pack',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        const Text(
          'اتكلم بذكاء وماتوضحش المكان أوي علشان الجاسوس مايعرفوش!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSpyContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.accentCoral.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.visibility, color: AppTheme.accentCoral, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentCoral.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'أنت الجاسوس! 🕵️',
            style: TextStyle(
              color: AppTheme.accentCoral,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'حاول تعرف المكان من أسئلة الباقيين من غير ما يكشفوك!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
