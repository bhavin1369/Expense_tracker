import '../utils/constants.dart';

class UserSettingsModel {
  final int id;
  final String userName;
  final bool shakeEnabled;
  final bool backgroundShakeEnabled;
  final double shakeSensitivity;
  final String shakeSensitivityLevel; // 'low', 'medium', 'high'
  final int shakeCooldown;
  final String currency;
  final String currencySymbol;
  final String theme;
  final String? excelFilePath;
  final DateTime? lastExcelSync;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettingsModel({
    this.id = 1,
    this.userName = AppConstants.defaultUserName,
    this.shakeEnabled = true,
    this.backgroundShakeEnabled = false,
    double? shakeSensitivity,
    String? shakeSensitivityLevel,
    this.shakeCooldown = AppConstants.defaultShakeCooldown,
    this.currency = AppConstants.defaultCurrency,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.theme = AppConstants.defaultTheme,
    this.excelFilePath,
    this.lastExcelSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : shakeSensitivityLevel = shakeSensitivityLevel ?? _resolveLevel(shakeSensitivity),
        shakeSensitivity = shakeSensitivity != null && shakeSensitivity <= 6.0
            ? shakeSensitivity
            : _resolveThreshold(shakeSensitivityLevel ?? _resolveLevel(shakeSensitivity)),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String _resolveLevel(double? threshold) {
    if (threshold == null || threshold > 6.0) return AppConstants.defaultShakeSensitivityLevel;
    if (threshold <= 2.7) return 'high';
    if (threshold <= 3.8) return 'medium';
    return 'low';
  }

  static double _resolveThreshold(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return AppConstants.shakeThresholdHigh;
      case 'low':
        return AppConstants.shakeThresholdLow;
      case 'medium':
      default:
        return AppConstants.shakeThresholdMedium;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'shake_enabled': shakeEnabled ? 1 : 0,
      'background_shake_enabled': backgroundShakeEnabled ? 1 : 0,
      'shake_sensitivity': shakeSensitivity,
      'shake_sensitivity_level': shakeSensitivityLevel,
      'shake_cooldown': shakeCooldown,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'theme': theme,
      'excel_file_path': excelFilePath,
      'last_excel_sync': lastExcelSync?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    final rawSens = (map['shake_sensitivity'] as num?)?.toDouble();
    final rawLevel = map['shake_sensitivity_level'] as String?;

    return UserSettingsModel(
      id: map['id'] as int? ?? 1,
      userName: map['user_name'] as String? ?? AppConstants.defaultUserName,
      shakeEnabled: (map['shake_enabled'] as int? ?? 1) == 1,
      backgroundShakeEnabled: (map['background_shake_enabled'] as int? ?? 0) == 1,
      shakeSensitivity: rawSens,
      shakeSensitivityLevel: rawLevel,
      shakeCooldown: map['shake_cooldown'] as int? ?? AppConstants.defaultShakeCooldown,
      currency: map['currency'] as String? ?? AppConstants.defaultCurrency,
      currencySymbol: map['currency_symbol'] as String? ?? AppConstants.defaultCurrencySymbol,
      theme: map['theme'] as String? ?? AppConstants.defaultTheme,
      excelFilePath: map['excel_file_path'] as String?,
      lastExcelSync: map['last_excel_sync'] != null
          ? DateTime.tryParse(map['last_excel_sync'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  UserSettingsModel copyWith({
    int? id,
    String? userName,
    bool? shakeEnabled,
    bool? backgroundShakeEnabled,
    double? shakeSensitivity,
    String? shakeSensitivityLevel,
    int? shakeCooldown,
    String? currency,
    String? currencySymbol,
    String? theme,
    String? excelFilePath,
    DateTime? lastExcelSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newLevel = shakeSensitivityLevel ?? (shakeSensitivity != null ? _resolveLevel(shakeSensitivity) : this.shakeSensitivityLevel);
    final newThreshold = shakeSensitivity ?? (shakeSensitivityLevel != null ? _resolveThreshold(shakeSensitivityLevel) : this.shakeSensitivity);

    return UserSettingsModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      backgroundShakeEnabled: backgroundShakeEnabled ?? this.backgroundShakeEnabled,
      shakeSensitivity: newThreshold,
      shakeSensitivityLevel: newLevel,
      shakeCooldown: shakeCooldown ?? this.shakeCooldown,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      theme: theme ?? this.theme,
      excelFilePath: excelFilePath ?? this.excelFilePath,
      lastExcelSync: lastExcelSync ?? this.lastExcelSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
