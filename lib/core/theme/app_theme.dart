// Lamma - by Mohamed Ibrahim

import 'package:flutter/material.dart';

class AppColors {
  // Locked Design Tokens from Stitch
  static const Color background = Color(0xFF101428);
  static const Color card = Color(0xFF1B2140);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA9B0CC);

  // Semantic Accents
  static const Color generalAccent = Color(0xFFFFC233);
  static const Color triviaAccent = Color(0xFFFFC233);
  static const Color spyAccent = Color(0xFFFF6B5E);
  static const Color charadesAccent = Color(0xFF3DDBB0);

  // Status Colors
  static const Color correct = Color(0xFF3DDBB0);
  static const Color wrong = Color(0xFFFF6B5E);
  static const Color textOnAccent = Color(0xFF101428);
}

class AppDimensions {
  static const double horizontalPadding = 24.0;
  static const double cardRadius = 20.0;
  static const double buttonHeight = 56.0;
  static const double rowGap = 12.0;
  static const double buttonRadius = 9999.0;
}

class AppTheme {
  static const String fontFamily = 'Cairo';

  // Common Aliases
  static const Color bg = AppColors.background;
  static const Color cardBg = AppColors.card;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color accentSaffron = AppColors.triviaAccent;
  static const Color accentCoral = AppColors.spyAccent;
  static const Color accentMint = AppColors.charadesAccent;

  static ThemeData get theme => darkTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.generalAccent,
        secondary: AppColors.charadesAccent,
        tertiary: AppColors.spyAccent,
        error: AppColors.wrong,
        onSurface: AppColors.textPrimary,
        onPrimary: AppColors.textOnAccent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        // Title 28 bold
        headlineLarge: TextStyle(
          fontSize: 28.0,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.28,
        ),
        // Section title 20 bold
        headlineMedium: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        // Body bold 18
        bodyLarge: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.44,
        ),
        // Body regular 16
        bodyMedium: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        // Small hint 14
        bodySmall: TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.42,
        ),
      ),
    );
  }
}
