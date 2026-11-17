import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/models/user_settings_model.dart';
import 'package:expense_tracker/utils/currency_formatter.dart';
import 'package:expense_tracker/utils/constants.dart';
import 'package:expense_tracker/utils/date_utils.dart';
import 'package:expense_tracker/utils/icon_helper.dart';
import 'package:expense_tracker/services/shake_detection_service.dart';
import 'package:expense_tracker/services/excel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategoryModel Tests', () {
    test('Default 27 expense categories and 10 income categories are correctly defined', () {
      final expenseCategories = CategoryModel.defaultExpenseCategories;
      expect(expenseCategories.length, 27);

      final incomeCategories = CategoryModel.defaultIncomeCategories;
      expect(incomeCategories.length, 10);

      final allCategories = CategoryModel.defaultCategories;
      expect(allCategories.length, 37);

      final expenseNames = expenseCategories.map((c) => c.categoryName).toList();
      expect(expenseNames, contains('Food & Drinks'));
      expect(expenseNames, contains('Transportation'));
      expect(expenseNames, contains('Shopping'));
      expect(expenseNames, contains('Groceries'));
      expect(expenseNames, contains('Entertainment'));
      expect(expenseNames, contains('Bills & Utilities'));
      expect(expenseNames, contains('Health & Medical'));
      expect(expenseNames, contains('Education'));
      expect(expenseNames, contains('Travel'));
      expect(expenseNames, contains('Personal Care'));
      expect(expenseNames, contains('Rent & Housing'));
      expect(expenseNames, contains('Fuel'));
      expect(expenseNames, contains('Mobile & Internet'));
      expect(expenseNames, contains('Sports & Fitness'));
      expect(expenseNames, contains('Electronics'));
      expect(expenseNames, contains('Gifts & Donations'));
      expect(expenseNames, contains('Restaurants & Cafes'));
      expect(expenseNames, contains('Subscriptions'));
      expect(expenseNames, contains('Family'));
      expect(expenseNames, contains('Pets'));
      expect(expenseNames, contains('College Expenses'));
      expect(expenseNames, contains('Hostel Expenses'));
      expect(expenseNames, contains('Office Expenses'));
      expect(expenseNames, contains('Bike Maintenance'));
      expect(expenseNames, contains('Home Maintenance'));
      expect(expenseNames, contains('Online Orders'));
      expect(expenseNames, contains('Other'));

      final incomeNames = incomeCategories.map((c) => c.categoryName).toList();
      expect(incomeNames, contains('Salary'));
      expect(incomeNames, contains('Business Income'));
      expect(incomeNames, contains('Freelance'));
      expect(incomeNames, contains('Content Creation'));
      expect(incomeNames, contains('Investments'));
      expect(incomeNames, contains('Interest & Dividends'));
      expect(incomeNames, contains('Rental Income'));
      expect(incomeNames, contains('Commission & Incentives'));
      expect(incomeNames, contains('Pension'));
      expect(incomeNames, contains('Other Income'));
    });

    test('Category serialization to and from Map', () {
      final cat = CategoryModel(
        id: 1,
        categoryName: 'Freelance',
        icon: 'laptop_rounded',
        color: '#0D9488',
        isDefault: false,
        isActive: true,
        categoryType: 'income',
      );

      final map = cat.toMap();
      expect(map['category_name'], 'Freelance');
      expect(map['icon'], 'laptop_rounded');
      expect(map['color'], '#0D9488');
      expect(map['is_default'], 0);
      expect(map['is_active'], 1);
      expect(map['category_type'], 'income');

      final reconstructed = CategoryModel.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.categoryName, 'Freelance');
      expect(reconstructed.isDefault, false);
      expect(reconstructed.isActive, true);
      expect(reconstructed.categoryType, 'income');
    });
  });

  group('ExpenseModel Tests', () {
    test('Expense serialization to and from Map with transactionType and paymentMode', () {
      final now = DateTime(2026, 11, 16, 14, 30, 0);
      final expense = ExpenseModel(
        id: 10,
        transactionId: 'TXN-20261116-TEST1234',
        amount: 350.50,
        categoryId: 1,
        categoryName: 'Food & Drinks',
        note: 'Team lunch at cafe',
        expenseDate: now,
        expenseTime: '14:30:00',
        createdAt: now,
        updatedAt: now,
        isSyncedExcel: true,
        transactionType: 'expense',
        paymentMode: 'UPI',
        currency: '₹',
        deviceName: 'Android Test Device',
        syncStatus: 'Synced',
      );

      final map = expense.toMap();
      expect(map['transaction_id'], 'TXN-20261116-TEST1234');
      expect(map['amount'], 350.50);
      expect(map['category_id'], 1);
      expect(map['category_name'], 'Food & Drinks');
      expect(map['note'], 'Team lunch at cafe');
      expect(map['is_synced_excel'], 1);
      expect(map['transaction_type'], 'expense');
      expect(map['payment_mode'], 'UPI');
      expect(map['currency'], '₹');
      expect(map['device_name'], 'Android Test Device');
      expect(map['sync_status'], 'Synced');

      final reconstructed = ExpenseModel.fromMap(map);
      expect(reconstructed.id, 10);
      expect(reconstructed.transactionId, 'TXN-20261116-TEST1234');
      expect(reconstructed.amount, 350.50);
      expect(reconstructed.isSyncedExcel, true);
      expect(reconstructed.isExpense, true);
      expect(reconstructed.isIncome, false);
      expect(reconstructed.paymentMode, 'UPI');
      expect(reconstructed.currency, '₹');
    });

    test('Income transaction identification', () {
      final income = ExpenseModel(
        transactionId: 'INC-20261116-001',
        amount: 50000.0,
        categoryId: 101,
        categoryName: 'Salary',
        expenseDate: DateTime.now(),
        expenseTime: '10:00:00',
        transactionType: 'income',
        paymentMode: 'Bank Transfer',
      );

      expect(income.isIncome, true);
      expect(income.isExpense, false);
      expect(income.transactionType, 'income');
      expect(income.paymentMode, 'Bank Transfer');
    });
  });

  group('UserSettingsModel Tests', () {
    test('User Settings default values and serialization', () {
      final settings = UserSettingsModel(
        userName: 'Bhavin',
        shakeEnabled: true,
        backgroundShakeEnabled: true,
        shakeSensitivity: 3.0,
        shakeSensitivityLevel: 'medium',
        shakeCooldown: 2500,
        currency: 'INR',
        currencySymbol: '₹',
        theme: 'system',
      );

      final map = settings.toMap();
      expect(map['user_name'], 'Bhavin');
      expect(map['shake_enabled'], 1);
      expect(map['background_shake_enabled'], 1);
      expect(map['shake_sensitivity'], 3.0);
      expect(map['shake_sensitivity_level'], 'medium');
      expect(map['shake_cooldown'], 2500);
      expect(map['currency'], 'INR');
      expect(map['currency_symbol'], '₹');

      final reconstructed = UserSettingsModel.fromMap(map);
      expect(reconstructed.userName, 'Bhavin');
      expect(reconstructed.shakeEnabled, true);
      expect(reconstructed.backgroundShakeEnabled, true);
      expect(reconstructed.shakeSensitivity, 3.0);
      expect(reconstructed.shakeSensitivityLevel, 'medium');
    });

    test('User Settings sensitivity levels resolve correctly', () {
      final high = UserSettingsModel(shakeSensitivityLevel: 'high');
      expect(high.shakeSensitivity, AppConstants.shakeThresholdHigh);
      expect(high.shakeSensitivityLevel, 'high');

      final low = UserSettingsModel(shakeSensitivityLevel: 'low');
      expect(low.shakeSensitivity, AppConstants.shakeThresholdLow);
      expect(low.shakeSensitivityLevel, 'low');

      final medium = UserSettingsModel(shakeSensitivityLevel: 'medium');
      expect(medium.shakeSensitivity, AppConstants.shakeThresholdMedium);
      expect(medium.shakeSensitivityLevel, 'medium');
    });

    test('Legacy raw accelerometer sensitivity (>6.0) automatically migrates to medium linear', () {
      final legacy = UserSettingsModel(shakeSensitivity: 15.0);
      expect(legacy.shakeSensitivity, AppConstants.shakeThresholdMedium);
      expect(legacy.shakeSensitivityLevel, 'medium');
    });
  });

  group('Currency and Date Formatter Tests', () {
    test('CurrencyHelper formats amounts correctly', () {
      final formatted = CurrencyHelper.formatAmount(250.0, symbol: '₹');
      expect(formatted, contains('₹'));
      expect(formatted, contains('250'));

      final compact = CurrencyHelper.formatCompact(15000, symbol: '₹');
      expect(compact, '₹ 15.0k');
    });

    test('AppDateUtils greetings and date comparisons', () {
      final greeting = AppDateUtils.getGreeting('Bhavin');
      expect(greeting, contains('Bhavin'));

      final today = DateTime.now();
      expect(AppDateUtils.isToday(today), isTrue);
      expect(AppDateUtils.formatDate(today), 'Today');
    });
  });

  group('IconHelper Tests', () {
    test('Parses hex colors safely', () {
      final color = IconHelper.parseColor('#FF7043');
      expect(color.toARGB32(), isNotNull);

      final fallbackColor = IconHelper.parseColor('invalid-hex');
      expect(fallbackColor, isNotNull);
    });
  });

  group('Excel Workbook Structure Tests', () {
    test('Generates Transactions sheet with all 12 headers and proper columns', () {
      final excel = Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      final sheet = excel[ExcelService.sheetTransactions];
      excel.setDefaultSheet(ExcelService.sheetTransactions);

      final headers = ExcelService.transactionHeaders;
      expect(headers.length, 12);
      expect(headers, contains('Transaction ID'));
      expect(headers, contains('Date'));
      expect(headers, contains('Time'));
      expect(headers, contains('Amount'));
      expect(headers, contains('Currency'));
      expect(headers, contains('Category'));
      expect(headers, contains('Remarks'));
      expect(headers, contains('Device Name'));
      expect(headers, contains('Transaction Type'));
      expect(headers, contains('Created At'));
      expect(headers, contains('Updated At'));
      expect(headers, contains('Sync Status'));

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
            TextCellValue(headers[i]);
      }

      // Add a test row
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          TextCellValue('TXN-20261116-0001');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
          TextCellValue('2026-11-16');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value =
          TextCellValue('14:30:00');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value =
          DoubleCellValue(250.0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value =
          TextCellValue('₹');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value =
          TextCellValue('Food & Drinks');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value =
          TextCellValue('Lunch with team');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value =
          TextCellValue('Android Device');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1)).value =
          TextCellValue('Expense');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1)).value =
          TextCellValue('2026-11-16T14:30:00.000');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1)).value =
          TextCellValue('2026-11-16T14:30:00.000');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1)).value =
          TextCellValue('Synced');

      final bytes = excel.save();
      expect(bytes, isNotNull);

      // Verify decode
      final decoded = Excel.decodeBytes(bytes!);
      expect(decoded.sheets.containsKey(ExcelService.sheetTransactions), isTrue);
      final readSheet = decoded[ExcelService.sheetTransactions];
      expect(readSheet.maxRows, greaterThanOrEqualTo(2));
      expect(
        readSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value.toString(),
        'Transaction ID',
      );
      expect(
        readSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1)).value.toString(),
        'Expense',
      );
      expect(
        readSheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1)).value.toString(),
        'Synced',
      );
    });
  });

  group('ShakeDetectionService Tests', () {
    setUpAll(() {
      const MethodChannel sensorMethodChannel = MethodChannel('dev.fluttercommunity.plus/sensors/method');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        sensorMethodChannel,
        (call) async => null,
      );
    });

    test('ShakeDetectionService configuration and debugNotifier', () {
      final service = ShakeDetectionService.instance;
      service.configure(
        enabled: true,
        sensitivity: 3.2,
        cooldown: 2500,
        level: 'medium',
      );

      expect(service.isEnabled, isTrue);
      expect(service.threshold, 3.2);
      expect(service.cooldownMs, 2500);
      expect(service.sensitivityLevel, 'medium');

      final debugInfo = service.debugNotifier.value;
      expect(debugInfo.threshold, 3.2);
      expect(debugInfo.sensitivityLevel, 'medium');
      expect(debugInfo.requiredPeaks, 4);
    });

    test('ShakeDetectionService simulateShake triggers registered callback', () {
      final service = ShakeDetectionService.instance;
      bool callbackFired = false;

      service.registerCallback(() {
        callbackFired = true;
      });

      service.simulateShake();
      expect(callbackFired, isTrue);

      service.unregisterCallback();
    });

    test('ShakeDetectionService resetDebugCounters clears all rejected counts', () {
      final service = ShakeDetectionService.instance;
      service.resetDebugCounters();

      final info = service.debugNotifier.value;
      expect(info.rejectedSingleSpikes, 0);
      expect(info.rejectedTimeouts, 0);
      expect(info.rejectedTooFast, 0);
      expect(info.rejectedCooldowns, 0);
      expect(info.rejectedWalkingStairs, 0);
      expect(info.rejectedSameDirection, 0);
      expect(info.peakCount, 0);
      expect(info.state, 'IDLE');
    });
  });
}
