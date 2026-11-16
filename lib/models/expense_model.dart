import 'package:intl/intl.dart';

class ExpenseModel {
  final int? id;
  final String transactionId;
  final double amount;
  final int categoryId;
  final String categoryName;
  final String? note;
  final DateTime expenseDate;
  final String expenseTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSyncedExcel;

  ExpenseModel({
    this.id,
    required this.transactionId,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    this.note,
    DateTime? expenseDate,
    String? expenseTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSyncedExcel = false,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        expenseTime = expenseTime ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transaction_id': transactionId,
      'amount': amount,
      'category_id': categoryId,
      'category_name': categoryName,
      'note': note ?? '',
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'expense_time': expenseTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced_excel': isSyncedExcel ? 1 : 0,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      note: map['note'] as String?,
      expenseDate: map['expense_date'] != null
          ? DateTime.parse(map['expense_date'] as String)
          : DateTime.now(),
      expenseTime: map['expense_time'] as String? ?? '00:00:00',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      isSyncedExcel: (map['is_synced_excel'] as int? ?? 0) == 1,
    );
  }

  ExpenseModel copyWith({
    int? id,
    String? transactionId,
    double? amount,
    int? categoryId,
    String? categoryName,
    String? note,
    DateTime? expenseDate,
    String? expenseTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSyncedExcel,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      note: note ?? this.note,
      expenseDate: expenseDate ?? this.expenseDate,
      expenseTime: expenseTime ?? this.expenseTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSyncedExcel: isSyncedExcel ?? this.isSyncedExcel,
    );
  }
}
