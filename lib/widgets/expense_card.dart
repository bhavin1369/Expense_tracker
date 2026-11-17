import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';
import '../utils/icon_helper.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final String currencySymbol;
  final String categoryIcon;
  final String categoryColorHex;
  final VoidCallback onTap;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.currencySymbol,
    required this.categoryIcon,
    required this.categoryColorHex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = IconHelper.parseColor(categoryColorHex);
    final iconData = IconHelper.getIcon(categoryIcon);

    final displayDate = AppDateUtils.formatDate(expense.expenseDate);
    final displayTime = AppDateUtils.formatDisplayTime(expense.expenseTime);
    final isIncome = expense.isIncome;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category Icon Circle
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (isIncome ? const Color(0xFF059669) : catColor).withValues(alpha: isDark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: isIncome ? const Color(0xFF059669) : catColor, size: 23),
              ),
              const SizedBox(width: 14),

              // Details: Category Name, Amount, Note, Date/Time, Payment Mode
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top line: Category Name & Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  expense.categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              if (isIncome) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'INCOME',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isIncome ? "+" : "-"}${CurrencyHelper.formatAmount(expense.amount, symbol: currencySymbol)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isIncome ? const Color(0xFF059669) : (isDark ? Colors.white : const Color(0xFFE11D48)),
                          ),
                        ),
                      ],
                    ),

                    // Middle line: Note / Description (if available)
                    if (expense.note != null && expense.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        expense.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],

                    // Bottom line: Date & Time + Payment Mode Chip
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$displayDate, $displayTime',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (expense.paymentMode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expense.paymentMode,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
