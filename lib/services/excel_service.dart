import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';
import '../utils/constants.dart';

class ExcelSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final String? filePath;
  final bool isFileLocked;

  ExcelSyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.filePath,
    this.isFileLocked = false,
  });
}

class ExcelService {
  ExcelService._privateConstructor();
  static final ExcelService instance = ExcelService._privateConstructor();

  static const String sheetTransactions = AppConstants.excelSheetName; // 'Transactions'
  static const String sheetDashboard = AppConstants.excelDashboardSheetName; // 'Dashboard'
  static const String defaultFileName = AppConstants.defaultExcelFileName; // 'My_Expense_Tracker.xlsx'

  static const List<String> transactionHeaders = [
    'Transaction ID',
    'Date',
    'Time',
    'Amount',
    'Currency',
    'Category',
    'Remarks',
    'Device Name',
    'Transaction Type',
    'Created At',
    'Updated At',
    'Sync Status',
  ];

  /// Gets the permanent file path for My_Expense_Tracker.xlsx.
  Future<File> getPermanentExcelFile({String? customPath}) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      final customFile = File(customPath);
      if (await customFile.exists()) {
        return customFile;
      }
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(directory.path, defaultFileName);
    return File(filePath);
  }

  /// Initializes the permanent Excel file with both 'Transactions' and 'Dashboard' sheets.
  Future<File> ensurePermanentWorkbookExists({String? customPath}) async {
    final file = await getPermanentExcelFile(customPath: customPath);
    if (!await file.exists()) {
      await _createEmptyWorkbookWithHeaders(file);
    }
    return file;
  }

  /// Creates a clean workbook with the required 'Transactions' and 'Dashboard' sheets.
  Future<void> _createEmptyWorkbookWithHeaders(File file) async {
    final excel = Excel.createExcel();

    // Remove default Sheet1
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 1. Transactions Sheet
    final sheet = excel[sheetTransactions];
    excel.setDefaultSheet(sheetTransactions);

    // Apply Column widths for all 12 columns
    sheet.setColumnWidth(0, 36.0); // Transaction ID
    sheet.setColumnWidth(1, 14.0); // Date
    sheet.setColumnWidth(2, 12.0); // Time
    sheet.setColumnWidth(3, 16.0); // Amount
    sheet.setColumnWidth(4, 10.0); // Currency
    sheet.setColumnWidth(5, 24.0); // Category
    sheet.setColumnWidth(6, 32.0); // Remarks
    sheet.setColumnWidth(7, 22.0); // Device Name
    sheet.setColumnWidth(8, 18.0); // Transaction Type
    sheet.setColumnWidth(9, 24.0); // Created At
    sheet.setColumnWidth(10, 24.0); // Updated At
    sheet.setColumnWidth(11, 16.0); // Sync Status

    // Header cells styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1B263B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int col = 0; col < transactionHeaders.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(transactionHeaders[col]);
      cell.cellStyle = headerStyle;
    }

    // 2. Initialize Dashboard Sheet
    _buildDashboardSheet(excel, []);

    await _safeSaveExcel(excel, file);
  }

  /// Safely writes excel workbook with atomic .tmp file swap and lock detection.
  Future<void> _safeSaveExcel(Excel excel, File targetFile) async {
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Excel encoder returned null bytes');
    }

    await targetFile.parent.create(recursive: true);
    final tempFile = File('${targetFile.path}.tmp');

    // Write to temp file first
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (e) {
      // If direct delete/rename fails (e.g. Windows file lock or cross-link), try copy & delete temp
      try {
        await tempFile.copy(targetFile.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (inner) {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        throw FileSystemException(
          'Excel file is locked by another process (e.g. opened in Microsoft Excel or PC viewer): $inner',
          targetFile.path,
        );
      }
    }
  }

  /// Populates the 'Dashboard' sheet with KPI metrics, Expense breakdown, and Income breakdown.
  void _buildDashboardSheet(Excel excel, List<ExpenseModel> transactions) {
    final sheet = excel[sheetDashboard];

    // Column widths
    sheet.setColumnWidth(0, 28.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 16.0);

    // Header Style
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0F172A'),
      horizontalAlign: HorizontalAlign.Left,
    );

    final sectionStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
    );

    final kpiLabelStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    );

    final kpiValueStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
    );

    // Title Row
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('FINANCIAL SUMMARY DASHBOARD');
    titleCell.cellStyle = titleStyle;

    final updatedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    updatedCell.value = TextCellValue('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    updatedCell.cellStyle = titleStyle;

    // Calculate Metrics
    double totalIncome = 0;
    double totalExpense = 0;
    int count = transactions.length;
    final Map<String, double> expenseByCategory = {};
    final Map<String, double> incomeByCategory = {};

    for (final t in transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
        incomeByCategory[t.categoryName] = (incomeByCategory[t.categoryName] ?? 0) + t.amount;
      } else {
        totalExpense += t.amount;
        expenseByCategory[t.categoryName] = (expenseByCategory[t.categoryName] ?? 0) + t.amount;
      }
    }

    final netSavings = totalIncome - totalExpense;
    final avgTxn = count > 0 ? (totalExpense + totalIncome) / count : 0.0;

    String topExpenseCat = 'None';
    double topExpenseVal = 0;
    expenseByCategory.forEach((k, v) {
      if (v > topExpenseVal) {
        topExpenseVal = v;
        topExpenseCat = k;
      }
    });

    String topIncomeCat = 'None';
    double topIncomeVal = 0;
    incomeByCategory.forEach((k, v) {
      if (v > topIncomeVal) {
        topIncomeVal = v;
        topIncomeCat = k;
      }
    });

    // KPI Metrics Section
    final kpis = [
      ['Total Income (₹)', totalIncome.toStringAsFixed(2)],
      ['Total Expenses (₹)', totalExpense.toStringAsFixed(2)],
      ['Net Savings / Balance (₹)', netSavings.toStringAsFixed(2)],
      ['Total Transactions', count.toString()],
      ['Average Transaction (₹)', avgTxn.toStringAsFixed(2)],
      ['Highest Expense Category', '$topExpenseCat (${topExpenseVal.toStringAsFixed(2)})'],
      ['Top Income Source', '$topIncomeCat (${topIncomeVal.toStringAsFixed(2)})'],
    ];

    int row = 2;
    for (final item in kpis) {
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue(item[0]);
      c0.cellStyle = kpiLabelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(item[1]);
      c1.cellStyle = kpiValueStyle;
      row++;
    }

    row += 2;
    // Expense Breakdown Table
    final expHeader = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    expHeader.value = TextCellValue('EXPENSE BREAKDOWN BY CATEGORY');
    expHeader.cellStyle = sectionStyle;

    final expCol1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    expCol1.value = TextCellValue('Amount (₹)');
    expCol1.cellStyle = sectionStyle;

    final expCol2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    expCol2.value = TextCellValue('Share %');
    expCol2.cellStyle = sectionStyle;
    row++;

    final sortedExpenses = expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedExpenses) {
      final share = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0.0;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DoubleCellValue(entry.value);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue('${share.toStringAsFixed(1)}%');
      row++;
    }

    row += 2;
    // Income Breakdown Table
    final incHeader = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    incHeader.value = TextCellValue('INCOME BREAKDOWN BY SOURCE');
    incHeader.cellStyle = sectionStyle;

    final incCol1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    incCol1.value = TextCellValue('Amount (₹)');
    incCol1.cellStyle = sectionStyle;

    final incCol2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    incCol2.value = TextCellValue('Share %');
    incCol2.cellStyle = sectionStyle;
    row++;

    final sortedIncome = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedIncome) {
      final share = totalIncome > 0 ? (entry.value / totalIncome) * 100 : 0.0;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DoubleCellValue(entry.value);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue('${share.toStringAsFixed(1)}%');
      row++;
    }
  }

  /// Appends or updates a single expense/income in the permanent Excel workbook.
  Future<ExcelSyncResult> appendExpenseToWorkbook(
    ExpenseModel expense, {
    String? customPath,
    List<ExpenseModel>? allCurrentTransactions,
  }) async {
    try {
      final file = await ensurePermanentWorkbookExists(customPath: customPath);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel[sheetTransactions];

      // Check if Transaction ID already exists in Column A
      int existingRowIndex = -1;
      for (int r = 1; r < sheet.maxRows; r++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
        final val = cell.value?.toString().trim();
        if (val == expense.transactionId) {
          existingRowIndex = r;
          break;
        }
      }

      final targetRow = existingRowIndex != -1 ? existingRowIndex : sheet.maxRows;

      // Populate all 12 columns
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: targetRow)).value =
          TextCellValue(expense.transactionId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: targetRow)).value =
          TextCellValue(DateFormat('yyyy-MM-dd').format(expense.expenseDate));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: targetRow)).value =
          TextCellValue(expense.expenseTime);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: targetRow)).value =
          DoubleCellValue(expense.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: targetRow)).value =
          TextCellValue(expense.currency);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
          TextCellValue(expense.categoryName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
          TextCellValue(expense.remarks);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: targetRow)).value =
          TextCellValue(expense.deviceName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: targetRow)).value =
          TextCellValue(expense.isIncome ? 'Income' : 'Expense');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: targetRow)).value =
          TextCellValue(expense.createdAt.toIso8601String());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: targetRow)).value =
          TextCellValue(expense.updatedAt.toIso8601String());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: targetRow)).value =
          TextCellValue('Synced');

      // Update Dashboard sheet if full list is provided
      if (allCurrentTransactions != null) {
        _buildDashboardSheet(excel, allCurrentTransactions);
      }

      await _safeSaveExcel(excel, file);

      return ExcelSyncResult(
        success: true,
        message: 'Transaction synchronized with Excel',
        syncedCount: 1,
        filePath: file.path,
      );
    } on FileSystemException catch (fse) {
      debugPrint('Excel file lock detected: ${fse.message}');
      return ExcelSyncResult(
        success: false,
        message: 'Excel file is currently locked or open in another application. Saved locally in SQLite.',
        syncedCount: 0,
        isFileLocked: true,
      );
    } catch (e, stack) {
      debugPrint('Excel write error: $e\n$stack');
      return ExcelSyncResult(
        success: false,
        message: 'Excel sync error: $e',
        syncedCount: 0,
      );
    }
  }

  /// Synchronizes all pending expenses to the permanent Excel file.
  Future<ExcelSyncResult> syncPendingExpenses(
    List<ExpenseModel> pendingExpenses, {
    String? customPath,
    List<ExpenseModel>? allTransactions,
  }) async {
    if (pendingExpenses.isEmpty) {
      return ExcelSyncResult(
        success: true,
        message: 'All transactions are already synchronized with Excel',
        syncedCount: 0,
      );
    }

    try {
      final file = await ensurePermanentWorkbookExists(customPath: customPath);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel[sheetTransactions];

      final existingIds = <String>{};
      for (int r = 1; r < sheet.maxRows; r++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
        final val = cell.value?.toString().trim();
        if (val != null && val.isNotEmpty) {
          existingIds.add(val);
        }
      }

      int synced = 0;
      for (final expense in pendingExpenses) {
        if (!existingIds.contains(expense.transactionId)) {
          final targetRow = sheet.maxRows;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: targetRow)).value =
              TextCellValue(expense.transactionId);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: targetRow)).value =
              TextCellValue(DateFormat('yyyy-MM-dd').format(expense.expenseDate));
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: targetRow)).value =
              TextCellValue(expense.expenseTime);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: targetRow)).value =
              DoubleCellValue(expense.amount);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: targetRow)).value =
              TextCellValue(expense.currency);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
              TextCellValue(expense.categoryName);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
              TextCellValue(expense.remarks);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: targetRow)).value =
              TextCellValue(expense.deviceName);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: targetRow)).value =
              TextCellValue(expense.isIncome ? 'Income' : 'Expense');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: targetRow)).value =
              TextCellValue(expense.createdAt.toIso8601String());
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: targetRow)).value =
              TextCellValue(expense.updatedAt.toIso8601String());
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: targetRow)).value =
              TextCellValue('Synced');

          existingIds.add(expense.transactionId);
          synced++;
        }
      }

      if (allTransactions != null) {
        _buildDashboardSheet(excel, allTransactions);
      }

      await _safeSaveExcel(excel, file);

      return ExcelSyncResult(
        success: true,
        message: 'Successfully synchronized $synced pending transactions to Excel',
        syncedCount: synced,
        filePath: file.path,
      );
    } on FileSystemException catch (fse) {
      debugPrint('Excel file locked during bulk sync: ${fse.message}');
      return ExcelSyncResult(
        success: false,
        message: 'Excel file is currently locked. Transactions will sync once the file is unlocked.',
        syncedCount: 0,
        isFileLocked: true,
      );
    } catch (e) {
      return ExcelSyncResult(
        success: false,
        message: 'Synchronization failed: $e',
        syncedCount: 0,
      );
    }
  }

  /// Removes an expense row from the Excel file by transaction ID.
  Future<bool> deleteExpenseFromWorkbook(String txnId, {String? customPath, List<ExpenseModel>? remaining}) async {
    try {
      final file = await getPermanentExcelFile(customPath: customPath);
      if (!await file.exists()) return true;

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel[sheetTransactions];

      // Find matching row
      int foundRow = -1;
      for (int r = 1; r < sheet.maxRows; r++) {
        final val = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value?.toString().trim();
        if (val == txnId) {
          foundRow = r;
          break;
        }
      }

      if (foundRow != -1) {
        // Clear cells of that row or recreate
        if (remaining != null) {
          await recreateWorkbookFromSQLite(remaining, customPath: customPath);
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting expense from Excel: $e');
      return false;
    }
  }

  /// Recreates the permanent Excel workbook from scratch using all SQLite records.
  Future<ExcelSyncResult> recreateWorkbookFromSQLite(
    List<ExpenseModel> allExpenses, {
    String? customPath,
  }) async {
    try {
      final file = await getPermanentExcelFile(customPath: customPath);
      await _createEmptyWorkbookWithHeaders(file);

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel[sheetTransactions];

      for (int i = 0; i < allExpenses.length; i++) {
        final expense = allExpenses[i];
        final targetRow = i + 1;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: targetRow)).value =
            TextCellValue(expense.transactionId);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: targetRow)).value =
            TextCellValue(DateFormat('yyyy-MM-dd').format(expense.expenseDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: targetRow)).value =
            TextCellValue(expense.expenseTime);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: targetRow)).value =
            DoubleCellValue(expense.amount);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: targetRow)).value =
            TextCellValue(expense.currency);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
            TextCellValue(expense.categoryName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
            TextCellValue(expense.remarks);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: targetRow)).value =
            TextCellValue(expense.deviceName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: targetRow)).value =
            TextCellValue(expense.isIncome ? 'Income' : 'Expense');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: targetRow)).value =
            TextCellValue(expense.createdAt.toIso8601String());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: targetRow)).value =
            TextCellValue(expense.updatedAt.toIso8601String());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: targetRow)).value =
            TextCellValue('Synced');
      }

      // Rebuild Dashboard sheet
      _buildDashboardSheet(excel, allExpenses);

      await _safeSaveExcel(excel, file);

      return ExcelSyncResult(
        success: true,
        message: 'Workbook regenerated with ${allExpenses.length} transactions',
        syncedCount: allExpenses.length,
        filePath: file.path,
      );
    } on FileSystemException catch (fse) {
      return ExcelSyncResult(
        success: false,
        message: 'Excel file is locked: ${fse.message}',
        isFileLocked: true,
      );
    } catch (e) {
      return ExcelSyncResult(
        success: false,
        message: 'Recreation failed: $e',
      );
    }
  }

  /// Shares the permanent Excel workbook via native share sheet.
  Future<bool> sharePermanentExcelFile({String? customPath}) async {
    final file = await ensurePermanentWorkbookExists(customPath: customPath);
    if (await file.exists()) {
      final xFile = XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'My Expense Tracker permanent Excel workbook.',
          subject: 'My_Expense_Tracker.xlsx',
        ),
      );
      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    }
    return false;
  }

  /// Exports a customized Excel file for a specific date range or category filter.
  Future<File?> exportFilteredExcelFile(
    List<ExpenseModel> expenses, {
    required String fileName,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File(p.join(tempDir.path, fileName));

      final excel = Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      final sheet = excel[sheetTransactions];
      excel.setDefaultSheet(sheetTransactions);

      // Widths
      sheet.setColumnWidth(0, 36.0);
      sheet.setColumnWidth(1, 14.0);
      sheet.setColumnWidth(2, 12.0);
      sheet.setColumnWidth(3, 16.0);
      sheet.setColumnWidth(4, 10.0);
      sheet.setColumnWidth(5, 24.0);
      sheet.setColumnWidth(6, 32.0);
      sheet.setColumnWidth(7, 22.0);
      sheet.setColumnWidth(8, 18.0);
      sheet.setColumnWidth(9, 24.0);
      sheet.setColumnWidth(10, 24.0);
      sheet.setColumnWidth(11, 16.0);

      final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1B263B'),
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int col = 0; col < transactionHeaders.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(transactionHeaders[col]);
        cell.cellStyle = headerStyle;
      }

      for (int i = 0; i < expenses.length; i++) {
        final exp = expenses[i];
        final row = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            TextCellValue(exp.transactionId);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            TextCellValue(DateFormat('yyyy-MM-dd').format(exp.expenseDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
            TextCellValue(exp.expenseTime);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
            DoubleCellValue(exp.amount);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
            TextCellValue(exp.currency);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
            TextCellValue(exp.categoryName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
            TextCellValue(exp.remarks);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
            TextCellValue(exp.deviceName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
            TextCellValue(exp.isIncome ? 'Income' : 'Expense');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
            TextCellValue(exp.createdAt.toIso8601String());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value =
            TextCellValue(exp.updatedAt.toIso8601String());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value =
            TextCellValue('Synced');
      }

      _buildDashboardSheet(excel, expenses);

      await _safeSaveExcel(excel, targetFile);
      return targetFile;
    } catch (e) {
      debugPrint('Export filtered excel error: $e');
    }
    return null;
  }

  /// Parses an external Excel workbook to import transactions into SQLite.
  Future<List<Map<String, dynamic>>> parseImportExcelFile(File file) async {
    final List<Map<String, dynamic>> parsedRows = [];
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      String? targetSheetName;
      if (excel.sheets.containsKey(sheetTransactions)) {
        targetSheetName = sheetTransactions;
      } else if (excel.sheets.containsKey('Expenses')) {
        targetSheetName = 'Expenses';
      } else if (excel.sheets.isNotEmpty) {
        targetSheetName = excel.sheets.keys.first;
      }

      if (targetSheetName == null) return parsedRows;
      final sheet = excel[targetSheetName];

      for (int r = 1; r < sheet.maxRows; r++) {
        final txnCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value;
        final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value;
        final timeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value;
        final amountCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value;
        final categoryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value ??
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value;
        final noteCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).value ??
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value;
        final typeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: r)).value;

        if (amountCell == null) continue;

        double? amount;
        if (amountCell is DoubleCellValue) {
          amount = amountCell.value;
        } else if (amountCell is IntCellValue) {
          amount = amountCell.value.toDouble();
        } else {
          amount = double.tryParse(amountCell.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        if (amount == null || amount <= 0) continue;

        final txnId = txnCell?.toString().trim() ?? '';
        final dateStr = dateCell?.toString().trim() ?? '';
        final timeStr = timeCell?.toString().trim() ?? '12:00:00';
        final categoryName = categoryCell?.toString().trim() ?? 'Other';
        final noteStr = noteCell?.toString().trim() ?? '';
        final typeStr = typeCell?.toString().trim().toLowerCase() == 'income' ? 'income' : 'expense';

        parsedRows.add({
          'transaction_id': txnId.isNotEmpty ? txnId : 'IMPORT-${DateTime.now().millisecondsSinceEpoch}-$r',
          'amount': amount,
          'category_name': categoryName,
          'note': noteStr,
          'transaction_type': typeStr,
          'payment_mode': 'UPI',
          'expense_date': dateStr.isNotEmpty ? dateStr : DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'expense_time': timeStr,
        });
      }
    } catch (e) {
      debugPrint('Error parsing imported excel file: $e');
    }
    return parsedRows;
  }
}
