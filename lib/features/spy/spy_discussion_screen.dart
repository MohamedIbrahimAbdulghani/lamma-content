// Lamma - by Mohamed Ibrahim
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../data/providers/game_providers.dart';

class SpyDiscussionScreen extends ConsumerStatefulWidget {
  const SpyDiscussionScreen({super.key});

  @override
  ConsumerState<SpyDiscussionScreen> createState() => _SpyDiscussionScreenState();
}

class _SpyDiscussionScreenState extends ConsumerState<SpyDiscussionScreen> {
  Timer? _timer;
  late int _remainingSeconds;
  late int _totalSeconds;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(spySettingsProvider);
    _totalSeconds = settings.discussionMinutes * 60;
    _remainingSeconds = _totalSeconds > 0 ? _totalSeconds : 300;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        if (mounted) {
          context.go('/spy/voting');
        }
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
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = _totalSeconds > 0 ? (_remainingSeconds / _totalSeconds) : 0.0;

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
          'وقت النقاش',
          style: TextStyle(
            fontSize: 24,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CountdownRing(
                        progress: progress,
                        size: 210,
                        color: AppTheme.accentCoral,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$minutes:$seconds',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCoral,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'دقائق متبقية',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'اسألوا بعض من غير ما تقولوا الكلمة',
                        textAlign: TextAlign.center,
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
              PrimaryButton(
                title: 'ابدأ التصويت',
                icon: Icons.how_to_vote,
                accentColor: AppTheme.accentCoral,
                onPressed: () {
                  _timer?.cancel();
                  context.go('/spy/voting');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
