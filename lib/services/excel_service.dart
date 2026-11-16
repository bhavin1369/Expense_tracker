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

  ExcelSyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.filePath,
  });
}

class ExcelService {
  ExcelService._privateConstructor();
  static final ExcelService instance = ExcelService._privateConstructor();

  static const String sheetName = AppConstants.excelSheetName;
  static const String defaultFileName = AppConstants.defaultExcelFileName;

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

  /// Initializes the permanent Excel file if it doesn't already exist.
  Future<File> ensurePermanentWorkbookExists({String? customPath}) async {
    final file = await getPermanentExcelFile(customPath: customPath);
    if (!await file.exists()) {
      await _createEmptyWorkbookWithHeaders(file);
    }
    return file;
  }

  /// Creates a clean workbook with the required 'Expenses' sheet and formatted headers.
  Future<void> _createEmptyWorkbookWithHeaders(File file) async {
    final excel = Excel.createExcel();

    // Remove default Sheet1 if present
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Apply Column widths
    sheet.setColumnWidth(0, 36.0); // Transaction ID
    sheet.setColumnWidth(1, 14.0); // Date
    sheet.setColumnWidth(2, 12.0); // Time
    sheet.setColumnWidth(3, 16.0); // Amount
    sheet.setColumnWidth(4, 24.0); // Category
    sheet.setColumnWidth(5, 30.0); // Note
    sheet.setColumnWidth(6, 22.0); // Created At

    // Header cells styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1B263B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Transaction ID',
      'Date',
      'Time',
      'Amount',
      'Category',
      'Note',
      'Created At',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final bytes = excel.save();
    if (bytes != null) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  /// Appends a single expense to the permanent Excel file without overwriting existing data.
  Future<ExcelSyncResult> appendExpenseToWorkbook(
    ExpenseModel expense, {
    String? customPath,
  }) async {
    try {
      final file = await ensurePermanentWorkbookExists(customPath: customPath);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel[sheetName];

      // Check for duplicate Transaction ID in Column A
      final existingIds = <String>{};
      for (int r = 1; r < sheet.maxRows; r++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
        final val = cell.value?.toString().trim();
        if (val != null && val.isNotEmpty) {
          existingIds.add(val);
        }
      }

      if (existingIds.contains(expense.transactionId)) {
        return ExcelSyncResult(
          success: true,
          message: 'Transaction already exists in Excel',
          syncedCount: 1,
          filePath: file.path,
        );
      }

      final targetRow = sheet.maxRows;

      // Add expense row
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: targetRow)).value =
          TextCellValue(expense.transactionId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: targetRow)).value =
          TextCellValue(DateFormat('yyyy-MM-dd').format(expense.expenseDate));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: targetRow)).value =
          TextCellValue(expense.expenseTime);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: targetRow)).value =
          DoubleCellValue(expense.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: targetRow)).value =
          TextCellValue(expense.categoryName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
          TextCellValue(expense.note ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
          TextCellValue(expense.createdAt.toIso8601String());

      final updatedBytes = excel.save();
      if (updatedBytes != null) {
        await file.writeAsBytes(updatedBytes, flush: true);
      }

      return ExcelSyncResult(
        success: true,
        message: 'Expense appended to Excel successfully',
        syncedCount: 1,
        filePath: file.path,
      );
    } catch (e, stack) {
      debugPrint('Excel write error: $e\n$stack');
      return ExcelSyncResult(
        success: false,
        message: 'Excel file lock or access error: $e',
        syncedCount: 0,
      );
    }
  }

  /// Synchronizes all pending expenses to the permanent Excel file.
  Future<ExcelSyncResult> syncPendingExpenses(
    List<ExpenseModel> pendingExpenses, {
    String? customPath,
  }) async {
    if (pendingExpenses.isEmpty) {
      return ExcelSyncResult(
        success: true,
        message: 'All expenses are already synchronized with Excel',
        syncedCount: 0,
      );
    }

    try {
      final file = await ensurePermanentWorkbookExists(customPath: customPath);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel[sheetName];

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
              TextCellValue(expense.categoryName);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
              TextCellValue(expense.note ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
              TextCellValue(expense.createdAt.toIso8601String());

          existingIds.add(expense.transactionId);
          synced++;
        }
      }

      final updatedBytes = excel.save();
      if (updatedBytes != null) {
        await file.writeAsBytes(updatedBytes, flush: true);
      }

      return ExcelSyncResult(
        success: true,
        message: 'Successfully synchronized $synced pending expenses to Excel',
        syncedCount: synced,
        filePath: file.path,
      );
    } catch (e) {
      return ExcelSyncResult(
        success: false,
        message: 'Synchronization failed: $e',
        syncedCount: 0,
      );
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
      final sheet = excel[sheetName];

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
            TextCellValue(expense.categoryName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow)).value =
            TextCellValue(expense.note ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: targetRow)).value =
            TextCellValue(expense.createdAt.toIso8601String());
      }

      final updatedBytes = excel.save();
      if (updatedBytes != null) {
        await file.writeAsBytes(updatedBytes, flush: true);
      }

      return ExcelSyncResult(
        success: true,
        message: 'Workbook regenerated with ${allExpenses.length} transactions',
        syncedCount: allExpenses.length,
        filePath: file.path,
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
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Widths
      sheet.setColumnWidth(0, 36.0);
      sheet.setColumnWidth(1, 14.0);
      sheet.setColumnWidth(2, 12.0);
      sheet.setColumnWidth(3, 16.0);
      sheet.setColumnWidth(4, 24.0);
      sheet.setColumnWidth(5, 30.0);
      sheet.setColumnWidth(6, 22.0);

      final headers = [
        'Transaction ID',
        'Date',
        'Time',
        'Amount',
        'Category',
        'Note',
        'Created At',
      ];

      final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1B263B'),
      );

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(headers[col]);
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
            TextCellValue(exp.categoryName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
            TextCellValue(exp.note ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
            TextCellValue(exp.createdAt.toIso8601String());
      }

      final bytes = excel.save();
      if (bytes != null) {
        await targetFile.writeAsBytes(bytes, flush: true);
        return targetFile;
      }
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
      if (excel.sheets.containsKey(sheetName)) {
        targetSheetName = sheetName;
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
        final categoryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value;
        final noteCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value;

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

        parsedRows.add({
          'transaction_id': txnId.isNotEmpty ? txnId : 'IMPORT-${DateTime.now().millisecondsSinceEpoch}-$r',
          'amount': amount,
          'category_name': categoryName,
          'note': noteStr,
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
