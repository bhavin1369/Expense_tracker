import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../models/user_settings_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'expense_tracker.db';
  static const int _databaseVersion = 2;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        note TEXT,
        expense_date TEXT NOT NULL,
        expense_time TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced_excel INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indexes for high performance querying
    await db.execute('CREATE INDEX idx_expenses_date ON expenses (expense_date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses (category_id)');
    await db.execute('CREATE INDEX idx_expenses_transaction_id ON expenses (transaction_id)');

    // 3. Create user_settings table
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY,
        user_name TEXT NOT NULL,
        shake_enabled INTEGER NOT NULL DEFAULT 1,
        background_shake_enabled INTEGER NOT NULL DEFAULT 0,
        shake_sensitivity REAL NOT NULL DEFAULT 3.0,
        shake_sensitivity_level TEXT NOT NULL DEFAULT 'medium',
        shake_cooldown INTEGER NOT NULL DEFAULT 2500,
        currency TEXT NOT NULL DEFAULT 'INR',
        currency_symbol TEXT NOT NULL DEFAULT '₹',
        theme TEXT NOT NULL DEFAULT 'system',
        excel_file_path TEXT,
        last_excel_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Prepopulate default categories
    final batch = db.batch();
    for (final cat in CategoryModel.defaultCategories) {
      batch.insert('categories', cat.toMap());
    }
    // 5. Prepopulate initial settings
    batch.insert('user_settings', UserSettingsModel().toMap());
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE user_settings ADD COLUMN shake_sensitivity_level TEXT NOT NULL DEFAULT 'medium'");
      } catch (_) {}
    }
  }

  // ================= EXPENSE OPERATIONS ================= //

  Future<int> insertExpense(ExpenseModel expense) async {
    final db = await database;
    return await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateExpense(ExpenseModel expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> updateExpenseExcelSyncStatus(String transactionId, bool isSynced) async {
    final db = await database;
    return await db.update(
      'expenses',
      {
        'is_synced_excel': isSynced ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ExpenseModel?> getExpenseById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ExpenseModel.fromMap(maps.first);
    }
    return null;
  }

  Future<ExpenseModel?> getExpenseByTransactionId(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ExpenseModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ExpenseModel>> getAllExpenses({
    String? searchQuery,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String sortBy = 'expense_date', // 'expense_date', 'amount'
    bool ascending = false,
  }) async {
    final db = await database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(category_name LIKE ? OR note LIKE ?)');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    if (categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(categoryId);
    }

    if (startDate != null) {
      whereClauses.add('expense_date >= ?');
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
    }

    if (endDate != null) {
      whereClauses.add('expense_date <= ?');
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }

    if (minAmount != null) {
      whereClauses.add('amount >= ?');
      whereArgs.add(minAmount);
    }

    if (maxAmount != null) {
      whereClauses.add('amount <= ?');
      whereArgs.add(maxAmount);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final orderDirection = ascending ? 'ASC' : 'DESC';
    final orderByString = sortBy == 'amount'
        ? 'amount $orderDirection, id $orderDirection'
        : 'expense_date $orderDirection, expense_time $orderDirection, id $orderDirection';

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderByString,
    );

    return List.generate(maps.length, (i) => ExpenseModel.fromMap(maps[i]));
  }

  Future<List<ExpenseModel>> getPendingExcelExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'is_synced_excel = 0',
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => ExpenseModel.fromMap(maps[i]));
  }

  // ================= CATEGORY OPERATIONS ================= //

  Future<List<CategoryModel>> getAllCategories({bool activeOnly = true}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_default DESC, category_name ASC',
    );
    return List.generate(maps.length, (i) => CategoryModel.fromMap(maps[i]));
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CategoryModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> getCategoryExpenseCount(int categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE category_id = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> reassignCategoryAndArchive(int oldCategoryId, int newCategoryId, String newCategoryName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'expenses',
        {
          'category_id': newCategoryId,
          'category_name': newCategoryName,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'category_id = ?',
        whereArgs: [oldCategoryId],
      );
      await txn.update(
        'categories',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [oldCategoryId],
      );
    });
  }

  Future<int> deleteCategoryPermanently(int categoryId) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [categoryId],
    );
  }

  Future<void> restoreDefaultCategories() async {
    final db = await database;
    final batch = db.batch();
    for (final cat in CategoryModel.defaultCategories) {
      final existing = await db.query(
        'categories',
        where: 'category_name = ?',
        whereArgs: [cat.categoryName],
      );
      if (existing.isEmpty) {
        batch.insert('categories', cat.toMap());
      } else {
        batch.update(
          'categories',
          {
            'icon': cat.icon,
            'color': cat.color,
            'is_default': 1,
            'is_active': 1,
          },
          where: 'category_name = ?',
          whereArgs: [cat.categoryName],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  // ================= SETTINGS OPERATIONS ================= //

  Future<UserSettingsModel> getUserSettings() async {
    final db = await database;
    try {
      await db.execute('ALTER TABLE user_settings ADD COLUMN background_shake_enabled INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE user_settings ADD COLUMN shake_sensitivity_level TEXT NOT NULL DEFAULT 'medium'");
    } catch (_) {}
    final List<Map<String, dynamic>> maps = await db.query(
      'user_settings',
      where: 'id = 1',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserSettingsModel.fromMap(maps.first);
    }
    final defaultSettings = UserSettingsModel();
    await db.insert('user_settings', defaultSettings.toMap());
    return defaultSettings;
  }

  Future<int> updateUserSettings(UserSettingsModel settings) async {
    final db = await database;
    return await db.update(
      'user_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  // ================= RAW EXPORT / BACKUP / RESET ================= //

  Future<Map<String, dynamic>> exportBackupData() async {
    final db = await database;
    final categories = await db.query('categories');
    final expenses = await db.query('expenses');
    final settings = await db.query('user_settings');

    return {
      'version': _databaseVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'expenses': expenses,
      'settings': settings,
    };
  }

  Future<void> restoreBackupData(Map<String, dynamic> backupData) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('categories');
      await txn.delete('user_settings');

      if (backupData['categories'] != null) {
        for (final row in backupData['categories']) {
          await txn.insert('categories', Map<String, dynamic>.from(row));
        }
      }
      if (backupData['expenses'] != null) {
        for (final row in backupData['expenses']) {
          await txn.insert('expenses', Map<String, dynamic>.from(row));
        }
      }
      if (backupData['settings'] != null) {
        for (final row in backupData['settings']) {
          await txn.insert('user_settings', Map<String, dynamic>.from(row));
        }
      }
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('categories');
      for (final cat in CategoryModel.defaultCategories) {
        await txn.insert('categories', cat.toMap());
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
