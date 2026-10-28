// Lamma - by Mohamed Ibrahim
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ReconnectingScreen extends StatelessWidget {
  const ReconnectingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSaffron),
                backgroundColor: Color(0x33FFC233),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'بنحاول نرجّعك للغرفة...',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
