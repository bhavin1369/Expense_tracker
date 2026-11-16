import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/shake_detection_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import 'category_management_screen.dart';
import 'excel_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _editUserName(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Your Name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            hintText: 'e.g. Bhavin',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await settings.updateUserName(newName);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeCurrency(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CurrencyHelper.supportedCurrencies.length,
            itemBuilder: (context, index) {
              final c = CurrencyHelper.supportedCurrencies[index];
              final isSelected = c.code == settings.currency;
              return ListTile(
                leading: Text(
                  c.symbol,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: isSelected ? const Icon(Icons.check, color: AppColors.accentGreen) : null,
                onTap: () {
                  settings.updateCurrency(c.code);
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        if (!context.mounted) return;
        final settingsProvider = context.read<SettingsProvider>();
        final expenseProvider = context.read<ExpenseProvider>();
        final categoryProvider = context.read<CategoryProvider>();

        final success = await settingsProvider.restoreBackup(file);
        if (context.mounted) {
          if (success) {
            await expenseProvider.loadExpenses();
            await categoryProvider.loadCategories();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database restored successfully from backup!'),
                backgroundColor: AppColors.accentGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid backup file format.'),
                backgroundColor: AppColors.accentRed,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring backup: $e')),
        );
      }
    }
  }

  void _showBatteryGuidanceDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert_rounded, color: AppColors.primaryGold),
            SizedBox(width: 10),
            Text('Battery Saver Guidance'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Background Shake Detection',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The app uses an Android Foreground Service to detect shakes even when the app is in the background or other apps are open.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Prevent Android From Stopping Detection',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Some phone brands (Xiaomi, Samsung, Oppo, Vivo, OnePlus) close background apps to save battery. Tap below to exempt Expense Tracker from battery saver.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Exempt App'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await settings.requestBatteryOptimizationExemption();
            },
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Expense Data?'),
        content: const Text(
          'This will permanently delete all expense transactions and custom categories from your local SQLite database.\n\nDefault categories will be restored. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final expenseProvider = context.read<ExpenseProvider>();
              final categoryProvider = context.read<CategoryProvider>();
              await expenseProvider.clearAll();
              await categoryProvider.restoreDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All expense records cleared successfully'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
              }
            },
            child: const Text('Clear All Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // GROUP 1: PROFILE – CHANGE NAME
            // ==========================================
            _buildGroupHeader('1. PROFILE', isDark),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          settings.userName.isNotEmpty ? settings.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      settings.userName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    subtitle: const Text('Tap to change your name'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _editUserName(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.primaryGold),
                    title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${settings.currency} (${settings.currencySymbol})'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _changeCurrency(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ==========================================
            // GROUP 2: SHAKE – NORMAL AND BACKGROUND DETECTION
            // ==========================================
            _buildGroupHeader('2. SHAKE DETECTION', isDark),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Normal Shake Toggle
                  SwitchListTile(
                    title: const Text('Shake to Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Shake phone when app is open to log an expense'),
                    value: settings.shakeEnabled,
                    activeThumbColor: AppColors.primaryGold,
                    onChanged: (val) {
                      settings.updateShakeSettings(enabled: val);
                    },
                  ),
                  if (settings.shakeEnabled) ...[
                    const Divider(height: 1),
                    // Background Shake Toggle
                    SwitchListTile(
                      title: const Text('Background Shake Detection', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Shake phone even when app is closed or in another app'),
                      value: settings.backgroundShakeEnabled,
                      activeThumbColor: AppColors.accentGreen,
                      onChanged: (val) async {
                        await settings.updateBackgroundShakeEnabled(val);
                      },
                    ),
                    const Divider(height: 1),
                    // Live Status Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Background Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(
                                settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                    ? 'Listening in background'
                                    : settings.backgroundShakeEnabled
                                        ? 'Service starting...'
                                        : 'Disabled',
                                style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                      ? AppColors.accentGreen
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                    ? AppColors.accentGreen
                                    : Colors.grey,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                        ? AppColors.accentGreen
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                      ? 'ACTIVE'
                                      : 'INACTIVE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: settings.backgroundShakeEnabled && settings.isBackgroundServiceRunning
                                        ? AppColors.accentGreen
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Battery Saver Exemption
                    ListTile(
                      leading: const Icon(Icons.battery_charging_full_rounded, color: AppColors.primaryGold),
                      title: const Text('Battery Saver Guidance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        settings.isBatteryOptimizationIgnored
                            ? 'Battery saver exempted (Recommended)'
                            : 'Tap to exempt app from battery saver',
                        style: TextStyle(fontSize: 12, color: settings.isBatteryOptimizationIgnored ? AppColors.accentGreen : null),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _showBatteryGuidanceDialog(context),
                    ),
                    const Divider(height: 1),
                    // Sensitivity Slider
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shake Sensitivity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              Text(
                                '${settings.shakeSensitivity.toStringAsFixed(1)} m/s²',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGold),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.shakeSensitivity,
                            min: 10.0,
                            max: 25.0,
                            divisions: 15,
                            activeColor: AppColors.primaryGold,
                            onChanged: (val) {
                              settings.updateShakeSettings(sensitivity: val);
                            },
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Easier shake', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              Text('Harder shake', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Test Shake Button
                    ListTile(
                      leading: const Icon(Icons.vibration_rounded, color: AppColors.primaryGold),
                      title: const Text('Test Shake Detection', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Test expense popup trigger'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: AppColors.darkNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          ShakeDetectionService.instance.simulateShake();
                        },
                        child: const Text('Test Now', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ==========================================
            // GROUP 3: APPEARANCE – LIGHT AND DARK MODE
            // ==========================================
            _buildGroupHeader('3. APPEARANCE', isDark),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildThemeTile(
                      context: context,
                      title: 'Light Mode',
                      subtitle: 'Clean white background',
                      icon: Icons.light_mode_rounded,
                      value: 'light',
                      current: settings.theme,
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildThemeTile(
                      context: context,
                      title: 'Dark Mode',
                      subtitle: 'Dark background for comfort',
                      icon: Icons.dark_mode_rounded,
                      value: 'dark',
                      current: settings.theme,
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildThemeTile(
                      context: context,
                      title: 'System Default',
                      subtitle: 'Match device setting automatically',
                      icon: Icons.brightness_auto_rounded,
                      value: 'system',
                      current: settings.theme,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ==========================================
            // GROUP 4: DATA – EXCEL FILE, BACKUP & RESTORE
            // ==========================================
            _buildGroupHeader('4. DATA & STORAGE', isDark),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Excel File Tile
                  ListTile(
                    leading: const Icon(Icons.table_chart_rounded, color: AppColors.accentGreen),
                    title: const Text('Excel File', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('View, sync, and share My_Expense_Tracker.xlsx'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExcelManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Backup Data
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.accentBlue),
                    title: const Text('Export Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Save or share a backup of all your data'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      final success = await settings.shareBackup();
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup shared successfully!'),
                            backgroundColor: AppColors.accentGreen,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  // Restore Data
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.accentPurple),
                    title: const Text('Restore Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Restore expenses from a backup file'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _restoreBackup(context),
                  ),
                  const Divider(height: 1),
                  // Manage Categories
                  ListTile(
                    leading: const Icon(Icons.category_rounded, color: AppColors.primaryGold),
                    title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Add, edit, or restore categories'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Clear All Data
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.accentRed),
                    title: const Text('Clear All Data', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accentRed)),
                    subtitle: const Text('Permanently reset all expenses'),
                    onTap: () => _confirmClearData(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String current,
    required bool isDark,
  }) {
    final isSelected = current == value;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryGold : (isDark ? Colors.white70 : Colors.black54),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.primaryGold : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGold, size: 22)
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<SettingsProvider>().updateTheme(value);
      },
    );
  }
}
