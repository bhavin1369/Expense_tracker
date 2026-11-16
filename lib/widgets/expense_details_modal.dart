import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';
import '../utils/icon_helper.dart';

class ExpenseDetailsModal extends StatelessWidget {
  final ExpenseModel expense;

  const ExpenseDetailsModal({super.key, required this.expense});

  static void show(BuildContext context, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseDetailsModal(expense: expense),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Are you sure you want to delete this expense of ${CurrencyHelper.formatAmount(expense.amount)} for "${expense.categoryName}"?\n\nThis will remove it from the database and update your permanent Excel workbook.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(); // close details modal
              final settings = context.read<SettingsProvider>();
              await context.read<ExpenseProvider>().deleteExpense(
                    expense.id!,
                    customExcelPath: settings.excelFilePath,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense deleted successfully'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    Navigator.of(context).pop(); // close modal
    showDialog(
      context: context,
      builder: (ctx) => _EditExpenseDialog(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final category = context.read<CategoryProvider>().categories.firstWhere(
          (c) => c.categoryName == expense.categoryName,
          orElse: () => context.read<CategoryProvider>().fallbackCategory,
        );

    final catColor = IconHelper.parseColor(category.color);
    final iconData = IconHelper.getIcon(category.icon);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: catColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.categoryName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        CurrencyHelper.formatAmount(expense.amount, symbol: currencySymbol),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('Transaction ID', expense.transactionId, isDark),
            _buildDetailRow(
              'Date & Time',
              '${AppDateUtils.formatFullDate(expense.expenseDate)} at ${AppDateUtils.formatDisplayTime(expense.expenseTime)}',
              isDark,
            ),
            if (expense.note != null && expense.note!.trim().isNotEmpty)
              _buildDetailRow('Description / Note', expense.note!, isDark),
            _buildDetailRow(
              'Excel Workbook Sync',
              expense.isSyncedExcel ? 'Synchronized (Row appended)' : 'Pending Synchronization',
              isDark,
              statusColor: expense.isSyncedExcel ? AppColors.accentGreen : AppColors.accentOrange,
            ),
            _buildDetailRow('Logged At', AppDateUtils.formatDateTime(expense.createdAt), isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showEditDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showDeleteConfirmation(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: statusColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditExpenseDialog extends StatefulWidget {
  final ExpenseModel expense;

  const _EditExpenseDialog({required this.expense});

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late CategoryModel _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.expense.amount.toString());
    _noteController = TextEditingController(text: widget.expense.note ?? '');
    final categories = context.read<CategoryProvider>().categories;
    _selectedCategory = categories.firstWhere(
      (c) => c.categoryName == widget.expense.categoryName,
      orElse: () => context.read<CategoryProvider>().fallbackCategory,
    );
    _selectedDate = widget.expense.expenseDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    final updated = widget.expense.copyWith(
      amount: amount,
      categoryId: _selectedCategory.id ?? 1,
      categoryName: _selectedCategory.categoryName,
      note: _noteController.text.trim(),
      expenseDate: _selectedDate,
      updatedAt: DateTime.now(),
    );

    final settings = context.read<SettingsProvider>();
    await context.read<ExpenseProvider>().updateExpense(
          updated,
          customExcelPath: settings.excelFilePath,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;

    return AlertDialog(
      title: const Text('Edit Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CategoryModel>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.categoryName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
