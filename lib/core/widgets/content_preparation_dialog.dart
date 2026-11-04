// Lamma - Content Preparation Dialog & Loader
// مؤشر تحميل متقدم بشريط تقدم حقيقي وسقف زمني وخيار البدء الجزئي عند المهلة

import 'dart:async';
import 'package:flutter/material.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

enum PreparationResultType {
  ready,
  partialStart,
  cancelled,
  error,
}

class PreparationResult {
  final PreparationResultType type;
  final int count;
  final String? errorMessage;

  const PreparationResult({
    required this.type,
    this.count = 0,
    this.errorMessage,
  });
}

class ContentPreparationDialog extends StatefulWidget {
  final String gameTitle;
  final String categoryName;
  final int targetCount;
  final Color accentColor;
  final ValueNotifier<int> progressNotifier;
  final ValueNotifier<String?> statusNotifier;
  final Future<bool> Function() onStartGeneration;
  final VoidCallback onCancel;

  const ContentPreparationDialog({
    super.key,
    required this.gameTitle,
    required this.categoryName,
    required this.targetCount,
    required this.accentColor,
    required this.progressNotifier,
    required this.statusNotifier,
    required this.onStartGeneration,
    required this.onCancel,
  });

  static Future<PreparationResult?> show(
    BuildContext context, {
    required String gameTitle,
    required String categoryName,
    required int targetCount,
    required Color accentColor,
    required ValueNotifier<int> progressNotifier,
    required ValueNotifier<String?> statusNotifier,
    required Future<bool> Function() onStartGeneration,
    required VoidCallback onCancel,
  }) {
    return showDialog<PreparationResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ContentPreparationDialog(
        gameTitle: gameTitle,
        categoryName: categoryName,
        targetCount: targetCount,
        accentColor: accentColor,
        progressNotifier: progressNotifier,
        statusNotifier: statusNotifier,
        onStartGeneration: onStartGeneration,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<ContentPreparationDialog> createState() => _ContentPreparationDialogState();
}

class _ContentPreparationDialogState extends State<ContentPreparationDialog> {
  static const int kTimeoutSeconds = 25;
  int _secondsLeft = kTimeoutSeconds;
  Timer? _countdownTimer;
  bool _isTimedOut = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    widget.progressNotifier.addListener(_checkProgress);
    _startTimer();
    _runGeneration();
  }

  void _startTimer() {
    _secondsLeft = kTimeoutSeconds;
    _isTimedOut = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          _isTimedOut = true;
          timer.cancel();
        }
      });
    });
  }

  void _checkProgress() {
    if (_isFinished || !mounted) return;
    final current = widget.progressNotifier.value;
    if (current >= widget.targetCount) {
      _isFinished = true;
      _countdownTimer?.cancel();
      Navigator.of(context, rootNavigator: true).pop(
        PreparationResult(type: PreparationResultType.ready, count: current),
      );
    }
  }

  Future<void> _runGeneration() async {
    try {
      final success = await widget.onStartGeneration();
      if (!mounted || _isFinished) return;
      if (success && widget.progressNotifier.value >= widget.targetCount) {
        _isFinished = true;
        _countdownTimer?.cancel();
        Navigator.of(context, rootNavigator: true).pop(
          PreparationResult(
            type: PreparationResultType.ready,
            count: widget.progressNotifier.value,
          ),
        );
      }
    } catch (e) {
      if (!mounted || _isFinished) return;
      _isFinished = true;
      _countdownTimer?.cancel();
      Navigator.of(context, rootNavigator: true).pop(
        PreparationResult(
          type: PreparationResultType.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.progressNotifier.removeListener(_checkProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<int>(
            valueListenable: widget.progressNotifier,
            builder: (context, currentCount, _) {
              final progress = (widget.targetCount > 0)
                  ? (currentCount / widget.targetCount).clamp(0.0, 1.0)
                  : 0.0;

              if (_isTimedOut && currentCount > 0 && currentCount < widget.targetCount) {
                return _buildPartialTimeoutView(currentCount);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                          strokeWidth: 3.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'نجهّز محتوى جديد في ${widget.gameTitle}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قسم: ${widget.categoryName}',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جاري التجهيز...',
                        style: const TextStyle(
                          color: Color(0xFFB0B7C3),
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        '$currentCount من ${widget.targetCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.statusNotifier,
                    builder: (context, msg, _) {
                      return Text(
                        msg ?? 'توليد ذكي ومباشر بدون أي تكرار ⚡',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8E95A5),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      title: 'إلغاء ✕',
                      icon: Icons.close,
                      onPressed: () {
                        widget.onCancel();
                        Navigator.of(context, rootNavigator: true).pop(
                          const PreparationResult(type: PreparationResultType.cancelled),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPartialTimeoutView(int currentCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor.withValues(alpha: 0.15),
          ),
          child: const Center(
            child: Text('⏱️', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'استغرق التجهيز وقتاً أطول من المعتاد',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'تم تجهيز $currentCount من أصل ${widget.targetCount} أسئلة في قسم ${widget.categoryName}.\nهل تود بدء اللعب الآن بها أم متابعة الانتظار؟',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB0B7C3),
            fontSize: 14,
            height: 1.5,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'ابدأ بـ $currentCount سؤال 🚀',
          icon: Icons.play_arrow,
          accentColor: widget.accentColor,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(
              PreparationResult(
                type: PreparationResultType.partialStart,
                count: currentCount,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          title: 'تابع الانتظار ⏳',
          icon: Icons.hourglass_bottom,
          onPressed: () {
            setState(() {
              _startTimer();
            });
          },
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            widget.onCancel();
            Navigator.of(context, rootNavigator: true).pop(
              const PreparationResult(type: PreparationResultType.cancelled),
            );
          },
          child: const Text(
            'إلغاء والعودة للوبي',
            style: TextStyle(
              color: Color(0xFF8E95A5),
              fontFamily: 'Cairo',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
