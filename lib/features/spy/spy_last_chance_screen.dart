// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/countdown_ring.dart';

class SpyLastChanceScreen extends ConsumerStatefulWidget {
  const SpyLastChanceScreen({super.key});

  @override
  ConsumerState<SpyLastChanceScreen> createState() => _SpyLastChanceScreenState();
}

class _SpyLastChanceScreenState extends ConsumerState<SpyLastChanceScreen> {
  Timer? _timer;
  int _secondsLeft = 15;
  String? _selectedWord;
  final List<String> _words = [
    'محطة مصر',
    'مطار القاهرة',
    'برج الجيزة',
    'شاطئ المعمورة',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        if (mounted) {
          context.go('/spy/result');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _chooseWord(String word) {
    if (_selectedWord != null) return;
    setState(() {
      _selectedWord = word;
    });
    _timer?.cancel();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        context.go('/spy/result');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / 15.0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اتكشفت! خمّن الكلمة',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Countdown Ring
              Center(
                child: CountdownRing(
                  progress: progress,
                  size: 160,
                  color: AppTheme.accentCoral,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_secondsLeft',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCoral,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ثانية',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Word options
              Expanded(
                child: ListView.separated(
                  itemCount: _words.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final w = _words[index];
                    final isSelected = w == _selectedWord;
                    return InkWell(
                      onTap: () => _chooseWord(w),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentCoral : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.accentCoral : AppTheme.textSecondary,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF101428) : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
