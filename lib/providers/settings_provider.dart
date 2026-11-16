import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_settings_model.dart';
import '../services/backup_service.dart';
import '../services/background_shake_service.dart';
import '../services/settings_service.dart';
import '../services/shake_detection_service.dart';
import '../utils/currency_formatter.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService.instance;
  final BackupService _backupService = BackupService.instance;
  final ShakeDetectionService _shakeService = ShakeDetectionService.instance;
  final BackgroundShakeService _bgShakeService = BackgroundShakeService.instance;

  UserSettingsModel _settings = UserSettingsModel();
  bool _isLoading = true;
  bool _isBackgroundServiceRunning = false;
  bool _isBatteryOptimizationIgnored = false;
  bool _isOverlayPermissionGranted = false;

  UserSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;
  String get userName => _settings.userName;
  bool get shakeEnabled => _settings.shakeEnabled;
  bool get backgroundShakeEnabled => _settings.backgroundShakeEnabled;
  bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;
  bool get isBatteryOptimizationIgnored => _isBatteryOptimizationIgnored;
  bool get isOverlayPermissionGranted => _isOverlayPermissionGranted;
  double get shakeSensitivity => _settings.shakeSensitivity;
  int get shakeCooldown => _settings.shakeCooldown;
  String get currency => _settings.currency;
  String get currencySymbol => _settings.currencySymbol;
  String get theme => _settings.theme;
  String? get excelFilePath => _settings.excelFilePath;
  DateTime? get lastExcelSync => _settings.lastExcelSync;

  ThemeMode get themeMode {
    switch (_settings.theme.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _settingsService.loadSettings();

    // Configure shake detector
    _shakeService.configure(
      enabled: _settings.shakeEnabled,
      sensitivity: _settings.shakeSensitivity,
      cooldown: _settings.shakeCooldown,
    );

    // Initialize background service status and start if enabled
    if (_settings.backgroundShakeEnabled && _settings.shakeEnabled) {
      await _bgShakeService.startService(
        sensitivity: _settings.shakeSensitivity,
        cooldown: _settings.shakeCooldown,
      );
    }
    await checkBackgroundServiceStatus();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkBackgroundServiceStatus() async {
    _isBackgroundServiceRunning = await _bgShakeService.isServiceRunning();
    _isBatteryOptimizationIgnored = await _bgShakeService.isBatteryOptimizationIgnored();
    _isOverlayPermissionGranted = await _bgShakeService.isOverlayPermissionGranted();
    notifyListeners();
  }

  Future<void> checkOverlayPermissionStatus() async {
    _isOverlayPermissionGranted = await _bgShakeService.isOverlayPermissionGranted();
    notifyListeners();
  }

  Future<void> requestOverlayPermission() async {
    await _bgShakeService.requestOverlayPermission();
    await checkOverlayPermissionStatus();
  }

  Future<bool> showFloatingOverlay() async {
    return await _bgShakeService.showFloatingOverlay();
  }

  Future<void> updateBackgroundShakeEnabled(bool enabled) async {
    if (enabled) {
      await _bgShakeService.requestNotificationPermission();
      await _bgShakeService.startService(
        sensitivity: _settings.shakeSensitivity,
        cooldown: _settings.shakeCooldown,
      );
    } else {
      await _bgShakeService.stopService();
    }

    _settings = _settings.copyWith(
      backgroundShakeEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    await _settingsService.saveSettings(_settings);
    await checkBackgroundServiceStatus();
  }

  Future<void> requestBatteryOptimizationExemption() async {
    await _bgShakeService.requestIgnoreBatteryOptimization();
    await checkBackgroundServiceStatus();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _bgShakeService.openBatteryOptimizationSettings();
  }

  Future<void> updateUserName(String newName) async {
    if (newName.trim().isEmpty) return;
    _settings = _settings.copyWith(
      userName: newName.trim(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<void> updateShakeSettings({
    bool? enabled,
    double? sensitivity,
    int? cooldown,
  }) async {
    _settings = _settings.copyWith(
      shakeEnabled: enabled ?? _settings.shakeEnabled,
      shakeSensitivity: sensitivity ?? _settings.shakeSensitivity,
      shakeCooldown: cooldown ?? _settings.shakeCooldown,
      updatedAt: DateTime.now(),
    );
    _shakeService.configure(
      enabled: _settings.shakeEnabled,
      sensitivity: _settings.shakeSensitivity,
      cooldown: _settings.shakeCooldown,
    );
    if (_settings.backgroundShakeEnabled && _settings.shakeEnabled) {
      await _bgShakeService.startService(
        sensitivity: _settings.shakeSensitivity,
        cooldown: _settings.shakeCooldown,
      );
    } else if (!_settings.shakeEnabled) {
      await _bgShakeService.stopService();
    }
    await checkBackgroundServiceStatus();
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<void> updateCurrency(String currencyCode) async {
    final info = CurrencyHelper.getCurrencyInfo(currencyCode);
    _settings = _settings.copyWith(
      currency: info.code,
      currencySymbol: info.symbol,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<void> updateTheme(String themeString) async {
    _settings = _settings.copyWith(
      theme: themeString,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<void> updateExcelFilePath(String path) async {
    _settings = _settings.copyWith(
      excelFilePath: path,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<void> recordExcelSync() async {
    _settings = _settings.copyWith(
      lastExcelSync: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _settingsService.saveSettings(_settings);
  }

  Future<bool> shareBackup() async {
    return await _backupService.shareBackupFile();
  }

  Future<bool> restoreBackup(File file) async {
    final success = await _backupService.restoreFromBackupFile(file);
    if (success) {
      await initialize();
    }
    return success;
  }
}
