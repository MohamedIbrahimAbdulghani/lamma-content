// Lamma - by Mohamed Ibrahim

import 'package:flutter/widgets.dart';

class AppLifecycleDetector with WidgetsBindingObserver {
  final VoidCallback onViolation;
  final int graceSeconds;
  bool isMonitoring = false;
  DateTime? _pausedTime;

  AppLifecycleDetector({
    required this.onViolation,
    this.graceSeconds = 2,
  });

  void start() {
    isMonitoring = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    isMonitoring = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isMonitoring) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!).inSeconds;
        _pausedTime = null;
        if (elapsed >= graceSeconds) {
          onViolation();
        }
      }
    }
  }
}
