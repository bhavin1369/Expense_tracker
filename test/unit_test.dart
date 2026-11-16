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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategoryModel Tests', () {
    test('Default 27 categories are correctly defined', () {
      final categories = CategoryModel.defaultCategories;
      expect(categories.length, 27);

      final categoryNames = categories.map((c) => c.categoryName).toList();
      expect(categoryNames, contains('Food & Drinks'));
      expect(categoryNames, contains('Transportation'));
      expect(categoryNames, contains('Shopping'));
      expect(categoryNames, contains('Groceries'));
      expect(categoryNames, contains('Entertainment'));
      expect(categoryNames, contains('Bills & Utilities'));
      expect(categoryNames, contains('Health & Medical'));
      expect(categoryNames, contains('Education'));
      expect(categoryNames, contains('Travel'));
      expect(categoryNames, contains('Personal Care'));
      expect(categoryNames, contains('Rent & Housing'));
      expect(categoryNames, contains('Fuel'));
      expect(categoryNames, contains('Mobile & Internet'));
      expect(categoryNames, contains('Sports & Fitness'));
      expect(categoryNames, contains('Electronics'));
      expect(categoryNames, contains('Gifts & Donations'));
      expect(categoryNames, contains('Restaurants & Cafes'));
      expect(categoryNames, contains('Subscriptions'));
      expect(categoryNames, contains('Family'));
      expect(categoryNames, contains('Pets'));
      expect(categoryNames, contains('College Expenses'));
      expect(categoryNames, contains('Hostel Expenses'));
      expect(categoryNames, contains('Office Expenses'));
      expect(categoryNames, contains('Bike Maintenance'));
      expect(categoryNames, contains('Home Maintenance'));
      expect(categoryNames, contains('Online Orders'));
      expect(categoryNames, contains('Other'));
    });

    test('Category serialization to and from Map', () {
      final cat = CategoryModel(
        id: 1,
        categoryName: 'Gaming',
        icon: 'sports_esports_rounded',
        color: '#AB47BC',
        isDefault: false,
        isActive: true,
      );

      final map = cat.toMap();
      expect(map['category_name'], 'Gaming');
      expect(map['icon'], 'sports_esports_rounded');
      expect(map['color'], '#AB47BC');
      expect(map['is_default'], 0);
      expect(map['is_active'], 1);

      final reconstructed = CategoryModel.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.categoryName, 'Gaming');
      expect(reconstructed.isDefault, false);
      expect(reconstructed.isActive, true);
    });
  });

  group('ExpenseModel Tests', () {
    test('Expense serialization to and from Map', () {
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
      );

      final map = expense.toMap();
      expect(map['transaction_id'], 'TXN-20261116-TEST1234');
      expect(map['amount'], 350.50);
      expect(map['category_id'], 1);
      expect(map['category_name'], 'Food & Drinks');
      expect(map['note'], 'Team lunch at cafe');
      expect(map['is_synced_excel'], 1);

      final reconstructed = ExpenseModel.fromMap(map);
      expect(reconstructed.id, 10);
      expect(reconstructed.transactionId, 'TXN-20261116-TEST1234');
      expect(reconstructed.amount, 350.50);
      expect(reconstructed.isSyncedExcel, true);
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
      expect(legacy.shakeSensitivity, 3.0);
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
    test('Generates Expenses sheet with bold headers and proper column cells', () {
      final excel = Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      final sheet = excel['Expenses'];
      excel.setDefaultSheet('Expenses');

      final headers = [
        'Transaction ID',
        'Date',
        'Time',
        'Amount',
        'Category',
        'Note',
        'Created At',
      ];

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
          TextCellValue('Food & Drinks');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value =
          TextCellValue('Lunch');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value =
          TextCellValue('2026-11-16T14:30:00.000');

      final bytes = excel.save();
      expect(bytes, isNotNull);

      // Verify decode
      final decoded = Excel.decodeBytes(bytes!);
      expect(decoded.sheets.containsKey('Expenses'), isTrue);
      final readSheet = decoded['Expenses'];
      expect(readSheet.maxRows, greaterThanOrEqualTo(2));
      expect(
        readSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value.toString(),
        'Transaction ID',
      );
      expect(
        readSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value.toString(),
        'TXN-20261116-0001',
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
        sensitivity: 3.0,
        cooldown: 2500,
        level: 'medium',
      );

      expect(service.isEnabled, isTrue);
      expect(service.threshold, 3.0);
      expect(service.cooldownMs, 2500);
      expect(service.sensitivityLevel, 'medium');

      final debugInfo = service.debugNotifier.value;
      expect(debugInfo.threshold, 3.0);
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

    test('ShakeDetectionService resetDebugCounters clears rejected counts', () {
      final service = ShakeDetectionService.instance;
      service.resetDebugCounters();

      final info = service.debugNotifier.value;
      expect(info.rejectedSingleSpikes, 0);
      expect(info.rejectedTimeouts, 0);
      expect(info.rejectedTooFast, 0);
      expect(info.rejectedCooldowns, 0);
      expect(info.peakCount, 0);
      expect(info.state, 'IDLE');
    });
  });
}
