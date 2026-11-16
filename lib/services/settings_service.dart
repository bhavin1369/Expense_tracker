import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user_settings_model.dart';
import '../utils/constants.dart';

class SettingsService {
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsFirstLaunch, false);
  }

  Future<UserSettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final dbSettings = await _dbHelper.getUserSettings();

    // Reconcile shared preferences with SQLite if needed
    final userName = prefs.getString(AppConstants.keyUserName) ?? dbSettings.userName;
    final shakeEnabled = prefs.getBool(AppConstants.keyShakeEnabled) ?? dbSettings.shakeEnabled;
    final backgroundShakeEnabled = prefs.getBool(AppConstants.keyBackgroundShakeEnabled) ?? dbSettings.backgroundShakeEnabled;
    final shakeSensitivityLevel = prefs.getString(AppConstants.keyShakeSensitivityLevel) ?? dbSettings.shakeSensitivityLevel;
    final shakeSensitivity = prefs.getDouble(AppConstants.keyShakeSensitivity) ?? dbSettings.shakeSensitivity;
    final shakeCooldown = prefs.getInt(AppConstants.keyShakeCooldown) ?? dbSettings.shakeCooldown;
    final currency = prefs.getString(AppConstants.keyCurrency) ?? dbSettings.currency;
    final currencySymbol = prefs.getString(AppConstants.keyCurrencySymbol) ?? dbSettings.currencySymbol;
    final theme = prefs.getString(AppConstants.keyTheme) ?? dbSettings.theme;
    final excelFilePath = prefs.getString(AppConstants.keyExcelFilePath) ?? dbSettings.excelFilePath;

    final resolved = dbSettings.copyWith(
      userName: userName,
      shakeEnabled: shakeEnabled,
      backgroundShakeEnabled: backgroundShakeEnabled,
      shakeSensitivity: shakeSensitivity,
      shakeSensitivityLevel: shakeSensitivityLevel,
      shakeCooldown: shakeCooldown,
      currency: currency,
      currencySymbol: currencySymbol,
      theme: theme,
      excelFilePath: excelFilePath,
    );

    return resolved;
  }

  Future<void> saveSettings(UserSettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, settings.userName);
    await prefs.setBool(AppConstants.keyShakeEnabled, settings.shakeEnabled);
    await prefs.setBool(AppConstants.keyBackgroundShakeEnabled, settings.backgroundShakeEnabled);
    await prefs.setString(AppConstants.keyShakeSensitivityLevel, settings.shakeSensitivityLevel);
    await prefs.setDouble(AppConstants.keyShakeSensitivity, settings.shakeSensitivity);
    await prefs.setInt(AppConstants.keyShakeCooldown, settings.shakeCooldown);
    await prefs.setString(AppConstants.keyCurrency, settings.currency);
    await prefs.setString(AppConstants.keyCurrencySymbol, settings.currencySymbol);
    await prefs.setString(AppConstants.keyTheme, settings.theme);
    if (settings.excelFilePath != null) {
      await prefs.setString(AppConstants.keyExcelFilePath, settings.excelFilePath!);
    }

    await _dbHelper.updateUserSettings(settings);
  }

  Future<void> updateUserName(String name) async {
    final current = await loadSettings();
    final updated = current.copyWith(
      userName: name.trim(),
      updatedAt: DateTime.now(),
    );
    await saveSettings(updated);
  }
}
