import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Shake Expense Tracker';
  static const String appVersion = '1.0.0';
  static const String defaultExcelFileName = 'My_Expense_Tracker.xlsx';
  static const String excelSheetName = 'Expenses';

  // Default Settings
  static const String defaultUserName = 'User';
  static const String defaultCurrency = 'INR';
  static const String defaultCurrencySymbol = '₹';

  // Shake Detection Algorithm Constants (Multi-Peak Linear Acceleration)
  static const String defaultShakeSensitivityLevel = 'medium';
  static const double shakeThresholdLow = 4.2; // m/s^2 linear acceleration (Strong deliberate shake)
  static const double shakeThresholdMedium = 3.0; // m/s^2 linear acceleration (Balanced, Default)
  static const double shakeThresholdHigh = 2.4; // m/s^2 linear acceleration (Lighter shake)
  static const double defaultShakeSensitivity = shakeThresholdMedium; // 3.0 m/s^2
  static const int defaultShakeCooldown = 2500; // ms (2.5s cooldown after successful shake)
  static const int minShakePeaks = 4; // At least 4 distinct alternating peaks required
  static const int maxShakeWindowMs = 1500; // 1.5s maximum detection window
  static const int minTimeBetweenPeaksMs = 100; // 100ms minimum interval to filter noise
  static const int maxTimeBetweenPeaksMs = 500; // 500ms maximum interval between peaks
  static const double shakeValleyRatio = 0.55; // Magnitude must drop below threshold * 0.55 before next peak

  static const String defaultTheme = 'system';

  // Storage Keys
  static const String keyUserName = 'user_name';
  static const String keyShakeEnabled = 'shake_enabled';
  static const String keyBackgroundShakeEnabled = 'background_shake_enabled';
  static const String keyShakeSensitivity = 'shake_sensitivity';
  static const String keyShakeSensitivityLevel = 'shake_sensitivity_level';
  static const String keyShakeCooldown = 'shake_cooldown';
  static const String keyShakeDebugLogsEnabled = 'shake_debug_logs_enabled';
  static const String keyCurrency = 'currency';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyTheme = 'theme';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyExcelFilePath = 'excel_file_path';
  static const String keyLastExcelSync = 'last_excel_sync';
}

class AppColors {
  // Primary Gold Palette (Warm, elegant accent)
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldLight = Color(0xFFF9F1D8);
  static const Color primaryGoldDark = Color(0xFFB8860B);

  // Navy Palette
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color navySurface = Color(0xFF1E293B);
  static const Color navyCard = Color(0xFF1E293B);
  static const Color navyBorder = Color(0xFF334155);

  // Light Mode Palette (Clean White backgrounds)
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF8F9FA);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Dark Mode Palette (Pure Dark backgrounds)
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2E2E2E);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Status & Accents
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentOrange = Color(0xFFF97316);
}
