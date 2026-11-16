import '../database/database_helper.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper;

  ExpenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> addExpense(ExpenseModel expense) async {
    return await _dbHelper.insertExpense(expense);
  }

  Future<int> updateExpense(ExpenseModel expense) async {
    return await _dbHelper.updateExpense(expense);
  }

  Future<int> deleteExpense(int id) async {
    return await _dbHelper.deleteExpense(id);
  }

  Future<ExpenseModel?> getExpenseById(int id) async {
    return await _dbHelper.getExpenseById(id);
  }

  Future<List<ExpenseModel>> getAllExpenses({
    String? searchQuery,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String sortBy = 'expense_date',
    bool ascending = false,
  }) async {
    return await _dbHelper.getAllExpenses(
      searchQuery: searchQuery,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      minAmount: minAmount,
      maxAmount: maxAmount,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  Future<List<ExpenseModel>> getPendingExpenses() async {
    return await _dbHelper.getPendingExcelExpenses();
  }

  Future<void> updateExcelSyncStatus(String transactionId, bool isSynced) async {
    await _dbHelper.updateExpenseExcelSyncStatus(transactionId, isSynced);
  }

  Future<int> importExpensesFromParsedData(
    List<Map<String, dynamic>> rows,
    List<CategoryModel> availableCategories,
  ) async {
    int imported = 0;
    final otherCategory = availableCategories.firstWhere(
      (c) => c.categoryName.toLowerCase() == 'other',
      orElse: () => availableCategories.first,
    );

    for (final row in rows) {
      final String txnId = row['transaction_id'];
      final existing = await _dbHelper.getExpenseByTransactionId(txnId);
      if (existing != null) continue;

      final catName = row['category_name'] as String;
      final matchedCat = availableCategories.firstWhere(
        (c) => c.categoryName.toLowerCase() == catName.toLowerCase(),
        orElse: () => otherCategory,
      );

      final expense = ExpenseModel(
        transactionId: txnId,
        amount: (row['amount'] as num).toDouble(),
        categoryId: matchedCat.id ?? otherCategory.id ?? 1,
        categoryName: matchedCat.categoryName,
        note: row['note'] as String?,
        expenseDate: DateTime.tryParse(row['expense_date'] as String) ?? DateTime.now(),
        expenseTime: row['expense_time'] as String? ?? '12:00:00',
        isSyncedExcel: true,
      );

      await _dbHelper.insertExpense(expense);
      imported++;
    }
    return imported;
  }

  Future<void> clearAll() async {
    await _dbHelper.clearAllData();
  }
}
