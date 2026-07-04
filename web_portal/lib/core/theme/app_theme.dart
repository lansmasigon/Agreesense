import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.text), // Dashboard Title
        displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.text), // Page Title
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text), // Section Title
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.text), // Body
        labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: AppColors.secondaryText), // Caption
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.card,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.text,
        onError: Colors.white,
      ),
    );
  }
}
