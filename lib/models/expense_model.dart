import 'package:intl/intl.dart';
import '../utils/constants.dart';

class ExpenseModel {
  final int? id;
  final String transactionId;
  final double amount;
  final int categoryId;
  final String categoryName;
  final String? note;
  final String transactionType; // 'expense' or 'income'
  final String paymentMode; // 'UPI', 'Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Other'
  final String currency; // 'INR', 'USD', etc.
  final String deviceName;
  final DateTime expenseDate;
  final String expenseTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus; // 'Pending', 'Synced', 'Failed'

  ExpenseModel({
    this.id,
    required this.transactionId,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    this.note,
    this.transactionType = AppConstants.typeExpense,
    this.paymentMode = 'UPI',
    this.currency = AppConstants.defaultCurrency,
    this.deviceName = AppConstants.defaultDeviceName,
    DateTime? expenseDate,
    String? expenseTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSyncedExcel,
    String? syncStatus,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        expenseTime = expenseTime ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        syncStatus = syncStatus ?? ((isSyncedExcel == true) ? 'Synced' : 'Pending');

  bool get isIncome => transactionType.toLowerCase() == AppConstants.typeIncome;
  bool get isExpense => !isIncome;
  bool get isSyncedExcel => syncStatus == 'Synced';
  String get remarks => note ?? '';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transaction_id': transactionId,
      'amount': amount,
      'category_id': categoryId,
      'category_name': categoryName,
      'note': note ?? '',
      'transaction_type': transactionType,
      'payment_mode': paymentMode,
      'currency': currency,
      'device_name': deviceName,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'expense_time': expenseTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced_excel': isSyncedExcel ? 1 : 0,
      'sync_status': syncStatus,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final isSynced = (map['is_synced_excel'] as int? ?? 0) == 1;
    final status = map['sync_status'] as String? ?? (isSynced ? 'Synced' : 'Pending');

    return ExpenseModel(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      note: map['note'] as String?,
      transactionType: map['transaction_type'] as String? ?? AppConstants.typeExpense,
      paymentMode: map['payment_mode'] as String? ?? 'UPI',
      currency: map['currency'] as String? ?? AppConstants.defaultCurrency,
      deviceName: map['device_name'] as String? ?? AppConstants.defaultDeviceName,
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
      syncStatus: status,
      isSyncedExcel: status == 'Synced',
    );
  }

  ExpenseModel copyWith({
    int? id,
    String? transactionId,
    double? amount,
    int? categoryId,
    String? categoryName,
    String? note,
    String? transactionType,
    String? paymentMode,
    String? currency,
    String? deviceName,
    DateTime? expenseDate,
    String? expenseTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSyncedExcel,
    String? syncStatus,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      note: note ?? this.note,
      transactionType: transactionType ?? this.transactionType,
      paymentMode: paymentMode ?? this.paymentMode,
      currency: currency ?? this.currency,
      deviceName: deviceName ?? this.deviceName,
      expenseDate: expenseDate ?? this.expenseDate,
      expenseTime: expenseTime ?? this.expenseTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSyncedExcel: isSyncedExcel ?? (syncStatus != null ? syncStatus == 'Synced' : this.isSyncedExcel),
      syncStatus: syncStatus ?? (isSyncedExcel != null ? (isSyncedExcel ? 'Synced' : 'Pending') : this.syncStatus),
    );
  }
}
