import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import '../services/excel_service.dart';
import '../utils/date_utils.dart';

class CategorySpending {
  final String categoryName;
  final double totalAmount;
  final String colorHex;
  final String icon;
  final double percentage;
  final int count;

  CategorySpending({
    required this.categoryName,
    required this.totalAmount,
    required this.colorHex,
    required this.icon,
    required this.percentage,
    required this.count,
  });
}

class MonthlySpending {
  final String monthLabel;
  final int monthIndex;
  final int year;
  final double totalAmount;

  MonthlySpending({
    required this.monthLabel,
    required this.monthIndex,
    required this.year,
    required this.totalAmount,
  });
}

class DailySpending {
  final String dayLabel;
  final DateTime date;
  final double totalAmount;

  DailySpending({
    required this.dayLabel,
    required this.date,
    required this.totalAmount,
  });
}

class ExpenseProvider with ChangeNotifier {
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final ExcelService _excelService = ExcelService.instance;
  final Uuid _uuid = const Uuid();

  List<ExpenseModel> _allExpenses = [];
  List<ExpenseModel> _filteredExpenses = [];
  bool _isLoading = true;

  // Filter / Search state
  String _searchQuery = '';
  int? _selectedCategoryId;
  String? _selectedTransactionType; // null = all, 'expense', 'income'
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  double? _filterMinAmount;
  double? _filterMaxAmount;
  String _sortBy = 'expense_date'; // 'expense_date', 'amount'
  bool _sortAscending = false;

  // Excel sync status
  int _pendingExcelCount = 0;
  bool _isExcelSyncing = false;
  String? _lastExcelMessage;

  // Getters
  List<ExpenseModel> get allExpenses => _allExpenses;
  List<ExpenseModel> get filteredExpenses => _filteredExpenses;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  String? get selectedTransactionType => _selectedTransactionType;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  double? get filterMinAmount => _filterMinAmount;
  double? get filterMaxAmount => _filterMaxAmount;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  int get pendingExcelCount => _pendingExcelCount;
  bool get isExcelSyncing => _isExcelSyncing;
  String? get lastExcelMessage => _lastExcelMessage;

  // Recent transactions (top 5)
  List<ExpenseModel> get recentExpenses => _allExpenses.take(5).toList();

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    _allExpenses = await _expenseRepository.getAllExpenses(
      sortBy: 'expense_date',
      ascending: false,
    );

    await _applyFiltersInternal();
    await _checkPendingExcelCount();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkPendingExcelCount() async {
    final pending = await _expenseRepository.getPendingExpenses();
    _pendingExcelCount = pending.length;
  }

  // ================= EXPENSE / INCOME ADD / EDIT / DELETE ================= //

  Future<bool> addExpense({
    required double amount,
    required int categoryId,
    required String categoryName,
    String? note,
    String transactionType = 'expense',
    String paymentMode = 'UPI',
    DateTime? date,
    TimeOfDay? time,
    String? customExcelPath,
  }) async {
    if (amount <= 0) return false;

    final expenseDate = date ?? DateTime.now();
    final expenseTime = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00'
        : DateFormat('HH:mm:ss').format(DateTime.now());

    final prefix = transactionType == 'income' ? 'INC' : 'TXN';
    final String txnId = '$prefix-${DateFormat('yyyyMMdd').format(expenseDate)}-${_uuid.v4().substring(0, 8).toUpperCase()}';

    final expense = ExpenseModel(
      transactionId: txnId,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      note: note?.trim(),
      expenseDate: expenseDate,
      expenseTime: expenseTime,
      isSyncedExcel: false,
      transactionType: transactionType,
      paymentMode: paymentMode,
      currency: '₹',
      syncStatus: 'Pending',
    );

    // 1. Save in SQLite first (Primary Source of Truth)
    final id = await _expenseRepository.addExpense(expense);
    final savedExpense = expense.copyWith(id: id);

    // 2. Append to the permanent Excel workbook
    final excelResult = await _excelService.appendExpenseToWorkbook(
      savedExpense,
      customPath: customExcelPath,
      allCurrentTransactions: [..._allExpenses, savedExpense],
    );

    if (excelResult.success) {
      await _expenseRepository.updateExcelSyncStatus(savedExpense.transactionId, true);
      _lastExcelMessage = excelResult.message;
    } else {
      _lastExcelMessage = 'Pending Excel sync: ${excelResult.message}';
    }

    // 3. Refresh in-memory state
    await loadExpenses();
    return true;
  }

  Future<bool> updateExpense(ExpenseModel updatedExpense, {String? customExcelPath}) async {
    final result = await _expenseRepository.updateExpense(updatedExpense);
    if (result > 0) {
      await loadExpenses();
      // Update workbook in background
      _excelService.recreateWorkbookFromSQLite(_allExpenses, customPath: customExcelPath);
      return true;
    }
    return false;
  }

  Future<bool> deleteExpense(int id, {String? customExcelPath}) async {
    final exp = _allExpenses.firstOrNullWhere((e) => e.id == id);
    final result = await _expenseRepository.deleteExpense(id);
    if (result > 0) {
      if (exp != null) {
        await _excelService.deleteExpenseFromWorkbook(
          exp.transactionId,
          customPath: customExcelPath,
          remaining: _allExpenses.where((e) => e.id != id).toList(),
        );
      }
      await loadExpenses();
      return true;
    }
    return false;
  }

  // ================= EXCEL SYNC & RECOVERY ================= //

  Future<ExcelSyncResult> syncPendingExpenses({String? customExcelPath}) async {
    _isExcelSyncing = true;
    notifyListeners();

    final pending = await _expenseRepository.getPendingExpenses();
    final result = await _excelService.syncPendingExpenses(
      pending,
      customPath: customExcelPath,
      allTransactions: _allExpenses,
    );

    if (result.success) {
      for (final p in pending) {
        await _expenseRepository.updateExcelSyncStatus(p.transactionId, true);
      }
    }

    _lastExcelMessage = result.message;
    _isExcelSyncing = false;
    await loadExpenses();
    return result;
  }

  Future<ExcelSyncResult> recreateWorkbook({String? customExcelPath}) async {
    _isExcelSyncing = true;
    notifyListeners();

    final result = await _excelService.recreateWorkbookFromSQLite(
      _allExpenses,
      customPath: customExcelPath,
    );

    if (result.success) {
      for (final exp in _allExpenses) {
        await _expenseRepository.updateExcelSyncStatus(exp.transactionId, true);
      }
    }

    _lastExcelMessage = result.message;
    _isExcelSyncing = false;
    await loadExpenses();
    return result;
  }

  Future<int> importFromExcelFile(File file, List<CategoryModel> categories) async {
    final parsedRows = await _excelService.parseImportExcelFile(file);
    if (parsedRows.isEmpty) return 0;

    final imported = await _expenseRepository.importExpensesFromParsedData(parsedRows, categories);
    await loadExpenses();
    return imported;
  }

  // ================= FILTER & SEARCH OPERATIONS ================= //

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersInternal();
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFiltersInternal();
    notifyListeners();
  }

  void setTransactionTypeFilter(String? type) {
    _selectedTransactionType = type;
    _applyFiltersInternal();
    notifyListeners();
  }

  void setDateRangeFilter(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    _applyFiltersInternal();
    notifyListeners();
  }

  void setAmountRangeFilter(double? min, double? max) {
    _filterMinAmount = min;
    _filterMaxAmount = max;
    _applyFiltersInternal();
    notifyListeners();
  }

  void setSorting(String sortBy, bool ascending) {
    _sortBy = sortBy;
    _sortAscending = ascending;
    _applyFiltersInternal();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _selectedTransactionType = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _filterMinAmount = null;
    _filterMaxAmount = null;
    _sortBy = 'expense_date';
    _sortAscending = false;
    _applyFiltersInternal();
    notifyListeners();
  }

  Future<void> _applyFiltersInternal() async {
    _filteredExpenses = await _expenseRepository.getAllExpenses(
      searchQuery: _searchQuery,
      categoryId: _selectedCategoryId,
      transactionType: _selectedTransactionType,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
      minAmount: _filterMinAmount,
      maxAmount: _filterMaxAmount,
      sortBy: _sortBy,
      ascending: _sortAscending,
    );
  }

  // ================= SUMMARY METRICS: EXPENSES & INCOME ================= //

  double get totalIncome {
    return _allExpenses.where((e) => e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalExpense {
    return _allExpenses.where((e) => e.isExpense).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get netBalance => totalIncome - totalExpense;

  double get todayTotal => todayExpense;

  double get todayExpense {
    return _allExpenses
        .where((e) => e.isExpense && AppDateUtils.isToday(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get todayIncome {
    return _allExpenses
        .where((e) => e.isIncome && AppDateUtils.isToday(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisWeekTotal => thisWeekExpense;

  double get thisWeekExpense {
    return _allExpenses
        .where((e) => e.isExpense && AppDateUtils.isThisWeek(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisWeekIncome {
    return _allExpenses
        .where((e) => e.isIncome && AppDateUtils.isThisWeek(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisMonthTotal => thisMonthExpense;

  double get thisMonthExpense {
    return _allExpenses
        .where((e) => e.isExpense && AppDateUtils.isThisMonth(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisMonthIncome {
    return _allExpenses
        .where((e) => e.isIncome && AppDateUtils.isThisMonth(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisMonthNetSavings => thisMonthIncome - thisMonthExpense;

  double get thisYearTotal => thisYearExpense;

  double get thisYearExpense {
    return _allExpenses
        .where((e) => e.isExpense && AppDateUtils.isThisYear(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisYearIncome {
    return _allExpenses
        .where((e) => e.isIncome && AppDateUtils.isThisYear(e.expenseDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  int get totalTransactionsCount => _allExpenses.length;

  double get allTimeTotal => totalExpense;

  // ================= DASHBOARD INSIGHTS ================= //

  CategorySpending? get mostUsedCategory {
    final expensesOnly = _allExpenses.where((e) => e.isExpense).toList();
    if (expensesOnly.isEmpty) return null;

    final counts = <String, int>{};
    final amounts = <String, double>{};
    for (final exp in expensesOnly) {
      counts[exp.categoryName] = (counts[exp.categoryName] ?? 0) + 1;
      amounts[exp.categoryName] = (amounts[exp.categoryName] ?? 0.0) + exp.amount;
    }

    String? topCategory;
    int maxCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topCategory = entry.key;
      }
    }

    if (topCategory == null) return null;
    final totalSpent = amounts[topCategory] ?? 0.0;
    final allTotal = totalExpense;
    final percentage = allTotal > 0 ? (totalSpent / allTotal) * 100 : 0.0;

    return CategorySpending(
      categoryName: topCategory,
      totalAmount: totalSpent,
      colorHex: '#FF7043',
      icon: 'category_rounded',
      percentage: percentage,
      count: maxCount,
    );
  }

  CategorySpending? get highestSpendingCategory {
    final expensesOnly = _allExpenses.where((e) => e.isExpense).toList();
    if (expensesOnly.isEmpty) return null;

    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final exp in expensesOnly) {
      amounts[exp.categoryName] = (amounts[exp.categoryName] ?? 0.0) + exp.amount;
      counts[exp.categoryName] = (counts[exp.categoryName] ?? 0) + 1;
    }

    String? topCategory;
    double maxAmount = -1;
    for (final entry in amounts.entries) {
      if (entry.value > maxAmount) {
        maxAmount = entry.value;
        topCategory = entry.key;
      }
    }

    if (topCategory == null) return null;
    final allTotal = totalExpense;
    final percentage = allTotal > 0 ? (maxAmount / allTotal) * 100 : 0.0;

    return CategorySpending(
      categoryName: topCategory,
      totalAmount: maxAmount,
      colorHex: '#D4AF37',
      icon: 'category_rounded',
      percentage: percentage,
      count: counts[topCategory] ?? 0,
    );
  }

  CategorySpending? get topIncomeSource {
    final incomeOnly = _allExpenses.where((e) => e.isIncome).toList();
    if (incomeOnly.isEmpty) return null;

    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final inc in incomeOnly) {
      amounts[inc.categoryName] = (amounts[inc.categoryName] ?? 0.0) + inc.amount;
      counts[inc.categoryName] = (counts[inc.categoryName] ?? 0) + 1;
    }

    String? topCategory;
    double maxAmount = -1;
    for (final entry in amounts.entries) {
      if (entry.value > maxAmount) {
        maxAmount = entry.value;
        topCategory = entry.key;
      }
    }

    if (topCategory == null) return null;
    final allIncome = totalIncome;
    final percentage = allIncome > 0 ? (maxAmount / allIncome) * 100 : 0.0;

    return CategorySpending(
      categoryName: topCategory,
      totalAmount: maxAmount,
      colorHex: '#10B981',
      icon: 'payments',
      percentage: percentage,
      count: counts[topCategory] ?? 0,
    );
  }

  List<CategorySpending> getCategoryWiseSpending(List<CategoryModel> categories) {
    final expensesOnly = _allExpenses.where((e) => e.isExpense).toList();
    if (expensesOnly.isEmpty) return [];

    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final exp in expensesOnly) {
      amounts[exp.categoryName] = (amounts[exp.categoryName] ?? 0.0) + exp.amount;
      counts[exp.categoryName] = (counts[exp.categoryName] ?? 0) + 1;
    }

    final total = totalExpense;
    final result = <CategorySpending>[];

    final categoryMap = {for (var c in categories) c.categoryName: c};

    for (final entry in amounts.entries) {
      final cat = categoryMap[entry.key];
      final colorHex = cat?.color ?? '#78909C';
      final icon = cat?.icon ?? 'category_rounded';
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;

      result.add(CategorySpending(
        categoryName: entry.key,
        totalAmount: entry.value,
        colorHex: colorHex,
        icon: icon,
        percentage: percentage,
        count: counts[entry.key] ?? 0,
      ));
    }

    result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return result;
  }

  List<CategorySpending> getCategoryWiseIncome(List<CategoryModel> categories) {
    final incomeOnly = _allExpenses.where((e) => e.isIncome).toList();
    if (incomeOnly.isEmpty) return [];

    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final inc in incomeOnly) {
      amounts[inc.categoryName] = (amounts[inc.categoryName] ?? 0.0) + inc.amount;
      counts[inc.categoryName] = (counts[inc.categoryName] ?? 0) + 1;
    }

    final total = totalIncome;
    final result = <CategorySpending>[];

    final categoryMap = {for (var c in categories) c.categoryName: c};

    for (final entry in amounts.entries) {
      final cat = categoryMap[entry.key];
      final colorHex = cat?.color ?? '#10B981';
      final icon = cat?.icon ?? 'payments';
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;

      result.add(CategorySpending(
        categoryName: entry.key,
        totalAmount: entry.value,
        colorHex: colorHex,
        icon: icon,
        percentage: percentage,
        count: counts[entry.key] ?? 0,
      ));
    }

    result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return result;
  }

  List<MonthlySpending> getLast6MonthsSpending() {
    final now = DateTime.now();
    final List<MonthlySpending> result = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final label = DateFormat('MMM').format(monthDate);
      final total = _allExpenses.where((e) {
        return e.isExpense && e.expenseDate.year == monthDate.year && e.expenseDate.month == monthDate.month;
      }).fold(0.0, (sum, e) => sum + e.amount);

      result.add(MonthlySpending(
        monthLabel: label,
        monthIndex: monthDate.month,
        year: monthDate.year,
        totalAmount: total,
      ));
    }

    return result;
  }

  List<DailySpending> getCurrentWeekDailySpending() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final List<DailySpending> result = [];

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final label = DateFormat('EEE').format(day);
      final total = _allExpenses.where((e) {
        return e.isExpense && AppDateUtils.isSameDay(e.expenseDate, day);
      }).fold(0.0, (sum, e) => sum + e.amount);

      result.add(DailySpending(
        dayLabel: label,
        date: day,
        totalAmount: total,
      ));
    }

    return result;
  }

  double get previousMonthTotal {
    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    return _allExpenses.where((e) {
      return e.isExpense && e.expenseDate.year == prevMonthDate.year && e.expenseDate.month == prevMonthDate.month;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  double get monthOverMonthPercentageChange {
    final prev = previousMonthTotal;
    final curr = thisMonthExpense;
    if (prev == 0) {
      return curr > 0 ? 100.0 : 0.0;
    }
    return ((curr - prev) / prev) * 100;
  }

  Future<void> clearAll() async {
    await _expenseRepository.clearAll();
    await loadExpenses();
  }
}

extension IterableExt<T> on Iterable<T> {
  T? firstOrNullWhere(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
