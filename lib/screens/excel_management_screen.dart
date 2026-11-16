import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/excel_service.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class ExcelManagementScreen extends StatefulWidget {
  const ExcelManagementScreen({super.key});

  @override
  State<ExcelManagementScreen> createState() => _ExcelManagementScreenState();
}

class _ExcelManagementScreenState extends State<ExcelManagementScreen> {
  String _permanentFilePath = '';
  int _fileSizeBytes = 0;
  bool _isLoadingFileInfo = true;

  @override
  void initState() {
    super.initState();
    _loadFileInfo();
  }

  Future<void> _loadFileInfo() async {
    setState(() => _isLoadingFileInfo = true);
    final settings = context.read<SettingsProvider>();
    final file = await ExcelService.instance.getPermanentExcelFile(
      customPath: settings.excelFilePath,
    );
    final exists = await file.exists();
    setState(() {
      _permanentFilePath = file.path;
      _fileSizeBytes = exists ? file.lengthSync() : 0;
      _isLoadingFileInfo = false;
    });
  }

  Future<void> _syncNow() async {
    final settings = context.read<SettingsProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    final result = await expenseProvider.syncPendingExpenses(
      customExcelPath: settings.excelFilePath,
    );

    if (mounted) {
      if (result.success) {
        await settings.recordExcelSync();
        await _loadFileInfo();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _shareWorkbook() async {
    final settings = context.read<SettingsProvider>();
    final success = await ExcelService.instance.sharePermanentExcelFile(
      customPath: settings.excelFilePath,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share Excel workbook')),
      );
    }
  }

  Future<void> _recreateWorkbook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recreate Excel Workbook?'),
        content: const Text(
          'This will regenerate "My_Expense_Tracker.xlsx" from your SQLite database records. All your expenses remain completely safe in SQLite.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Recreate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final settings = context.read<SettingsProvider>();
      final result = await context.read<ExpenseProvider>().recreateWorkbook(
            customExcelPath: settings.excelFilePath,
          );
      if (mounted) {
        if (result.success) {
          await settings.recordExcelSync();
          await _loadFileInfo();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        if (!mounted) return;
        final categories = context.read<CategoryProvider>().categories;
        final count = await context.read<ExpenseProvider>().importFromExcelFile(file, categories);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $count expenses from Excel!'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing Excel file: $e')),
        );
      }
    }
  }

  Future<void> _exportDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (range != null && mounted) {
      final expenses = context.read<ExpenseProvider>().allExpenses.where((e) {
        return (e.expenseDate.isAfter(range.start) || AppDateUtils.isSameDay(e.expenseDate, range.start)) &&
            (e.expenseDate.isBefore(range.end) || AppDateUtils.isSameDay(e.expenseDate, range.end));
      }).toList();

      final fileName = 'Expenses_${DateFormat('yyyyMMdd').format(range.start)}_to_${DateFormat('yyyyMMdd').format(range.end)}.xlsx';
      final file = await ExcelService.instance.exportFilteredExcelFile(expenses, fileName: fileName);

      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${expenses.length} expenses to $fileName'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenseProvider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();

    final pendingCount = expenseProvider.pendingExcelCount;
    final lastSyncText = settings.lastExcelSync != null
        ? AppDateUtils.formatDateTime(settings.lastExcelSync!)
        : 'Never';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Excel Integration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2B48), Color(0xFF1E3A5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: AppColors.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppConstants.defaultExcelFileName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              pendingCount == 0
                                  ? 'Fully Synchronized'
                                  : '$pendingCount pending synchronization',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: pendingCount == 0 ? AppColors.accentGreen : AppColors.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),
                  _buildStatusRow('Total Expenses Synced', '${expenseProvider.totalTransactionsCount} rows'),
                  _buildStatusRow('Last Sync', lastSyncText),
                  _buildStatusRow(
                    'File Size',
                    _fileSizeBytes > 0 ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB' : 'Created',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // File Path Box
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FILE LOCATION',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Path',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _permanentFilePath));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File path copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoadingFileInfo ? 'Loading...' : _permanentFilePath,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions Section
            Text(
              'Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildActionTile(
              icon: Icons.sync_rounded,
              iconColor: AppColors.primaryGold,
              title: 'Sync Now',
              subtitle: 'Append any pending offline transactions to the workbook',
              onTap: _syncNow,
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.share_rounded,
              iconColor: AppColors.accentBlue,
              title: 'Share Excel File',
              subtitle: 'Send My_Expense_Tracker.xlsx via WhatsApp, Email or Drive',
              onTap: _shareWorkbook,
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.date_range_rounded,
              iconColor: AppColors.accentGreen,
              title: 'Export Date Range',
              subtitle: 'Generate a separate Excel report for a selected period',
              onTap: _exportDateRange,
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.file_upload_rounded,
              iconColor: AppColors.accentPurple,
              title: 'Import from Excel',
              subtitle: 'Import expenses from an external .xlsx file into SQLite',
              onTap: _importFromExcel,
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.refresh_rounded,
              iconColor: AppColors.accentOrange,
              title: 'Recreate Excel Workbook',
              subtitle: 'Regenerate the permanent Excel workbook from SQLite source-of-truth',
              onTap: _recreateWorkbook,
              isDark: isDark,
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}
