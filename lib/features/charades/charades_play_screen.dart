// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/game_providers.dart';

enum FlashState { none, correct, pass }

class CharadesPlayScreen extends ConsumerStatefulWidget {
  const CharadesPlayScreen({super.key});

  @override
  ConsumerState<CharadesPlayScreen> createState() => _CharadesPlayScreenState();
}

class _CharadesPlayScreenState extends ConsumerState<CharadesPlayScreen> {
  Timer? _timer;
  late int _secondsLeft;
  int _wordIndex = 0;
  FlashState _flashState = FlashState.none;
  int _correctCount = 0;
  int _passedCount = 0;

  final List<String> _words = [
    'الفرح',
    'الكيف',
    'إبراهيم الأبيض',
    'الناظر',
    'صعيدي في الجامعة الأمريكية',
    'عسل أسود',
    'طيور الظلام',
    'الإرهاب والكباب',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(charadesSettingsProvider);
    _secondsLeft = settings.roundSeconds > 0 ? settings.roundSeconds : 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        if (mounted) {
          context.go('/charades/summary');
        }
      }
    });
  }

  void _onCorrect() {
    if (_flashState != FlashState.none) return;
    setState(() {
      _flashState = FlashState.correct;
      _correctCount++;
    });
    _nextWordAfterFlash();
  }

  void _onPass() {
    if (_flashState != FlashState.none) return;
    setState(() {
      _flashState = FlashState.pass;
      _passedCount++;
    });
    _nextWordAfterFlash();
  }

  void _nextWordAfterFlash() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _flashState = FlashState.none;
          _wordIndex = (_wordIndex + 1) % _words.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft ~/ 60).toString();
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final currentWord = _words[_wordIndex];

    return Scaffold(
      backgroundColor: _flashState == FlashState.correct
          ? AppTheme.accentMint
          : (_flashState == FlashState.pass ? AppTheme.accentCoral : AppTheme.bg),
      body: SafeArea(
        child: _flashState != FlashState.none
            ? _buildFlashContent()
            : _buildPlayContent(minutes, seconds, currentWord),
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
            isCorrect ? 'صح! 🎉' : 'تخطّي! ⏩',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101428),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayContent(String minutes, String seconds, String word) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Timer & Scores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صح: $_correctCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentMint,
                ),
              ),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentMint,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'تخطي: $_passedCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Word Display
          Center(
            child: Text(
              word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const Spacer(),

          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _onCorrect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentMint,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      '✔ صح',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101428),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _onPass,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.textSecondary, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'تخطّي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
