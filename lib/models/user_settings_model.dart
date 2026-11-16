import '../utils/constants.dart';

class UserSettingsModel {
  final int id;
  final String userName;
  final bool shakeEnabled;
  final bool backgroundShakeEnabled;
  final double shakeSensitivity;
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
    this.shakeSensitivity = AppConstants.defaultShakeSensitivity,
    this.shakeCooldown = AppConstants.defaultShakeCooldown,
    this.currency = AppConstants.defaultCurrency,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.theme = AppConstants.defaultTheme,
    this.excelFilePath,
    this.lastExcelSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'shake_enabled': shakeEnabled ? 1 : 0,
      'background_shake_enabled': backgroundShakeEnabled ? 1 : 0,
      'shake_sensitivity': shakeSensitivity,
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
    return UserSettingsModel(
      id: map['id'] as int? ?? 1,
      userName: map['user_name'] as String? ?? AppConstants.defaultUserName,
      shakeEnabled: (map['shake_enabled'] as int? ?? 1) == 1,
      backgroundShakeEnabled: (map['background_shake_enabled'] as int? ?? 0) == 1,
      shakeSensitivity: (map['shake_sensitivity'] as num?)?.toDouble() ?? AppConstants.defaultShakeSensitivity,
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
    int? shakeCooldown,
    String? currency,
    String? currencySymbol,
    String? theme,
    String? excelFilePath,
    DateTime? lastExcelSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettingsModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      backgroundShakeEnabled: backgroundShakeEnabled ?? this.backgroundShakeEnabled,
      shakeSensitivity: shakeSensitivity ?? this.shakeSensitivity,
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
