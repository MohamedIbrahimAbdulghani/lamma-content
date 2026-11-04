// Lamma - Game Prebuffer Progress Dialog
// Loader بهوية اللعبة وشريط تقدم عند انتظار اكتمال التجهيز المسبق

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GamePrebufferLoaderDialog extends StatelessWidget {
  final String gameTitle;
  final String statusText;
  final double progress; // 0.0 to 1.0

  const GamePrebufferLoaderDialog({
    super.key,
    required this.gameTitle,
    this.statusText = 'جاري تجهيز محتوى جديد كلياً بالذكاء الاصطناعي...',
    this.progress = 0.5,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String gameTitle,
    required Future<T> task,
    Duration timeout = const Duration(seconds: 4),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _PrebufferTaskRunner<T>(
          gameTitle: gameTitle,
          task: task,
          timeout: timeout,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentSaffron.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSaffron),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تجهيز $gameTitle ⚡',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B7C3),
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentSaffron),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrebufferTaskRunner<T> extends StatefulWidget {
  final String gameTitle;
  final Future<T> task;
  final Duration timeout;

  const _PrebufferTaskRunner({
    required this.gameTitle,
    required this.task,
    required this.timeout,
  });

  @override
  State<_PrebufferTaskRunner<T>> createState() => _PrebufferTaskRunnerState<T>();
}

class _PrebufferTaskRunnerState<T> extends State<_PrebufferTaskRunner<T>> {
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _startTask();
  }

  void _startTask() async {
    // Simulate animated micro-progress while waiting for parallel batch
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _progress = 0.6);
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _progress = 0.85);
    });

    try {
      final result = await widget.task.timeout(widget.timeout);
      if (mounted) {
        setState(() => _progress = 1.0);
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GamePrebufferLoaderDialog(
      gameTitle: widget.gameTitle,
      progress: _progress,
    );
  }
}
