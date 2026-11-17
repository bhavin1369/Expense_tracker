import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_details_modal.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedQuickPeriod = 'All'; // 'All', 'Today', 'This Week', 'This Month'
  String _selectedType = 'All'; // 'All', 'Expense', 'Income'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTypeSelected(String type) {
    HapticFeedback.selectionClick();
    setState(() => _selectedType = type);
    final expenseProvider = context.read<ExpenseProvider>();
    if (type == 'Expense') {
      expenseProvider.setTransactionTypeFilter('expense');
    } else if (type == 'Income') {
      expenseProvider.setTransactionTypeFilter('income');
    } else {
      expenseProvider.setTransactionTypeFilter(null);
    }
  }

  void _onQuickPeriodSelected(String period) {
    HapticFeedback.selectionClick();
    setState(() => _selectedQuickPeriod = period);

    final expenseProvider = context.read<ExpenseProvider>();
    final now = DateTime.now();

    switch (period) {
      case 'Today':
        final todayStart = DateTime(now.year, now.month, now.day);
        expenseProvider.setDateRangeFilter(todayStart, now);
        break;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        expenseProvider.setDateRangeFilter(DateTime(weekStart.year, weekStart.month, weekStart.day), now);
        break;
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        expenseProvider.setDateRangeFilter(monthStart, now);
        break;
      case 'All':
      default:
        expenseProvider.setDateRangeFilter(null, null);
        break;
    }
  }

  void _openCategoryFilterModal() {
    final categoryProvider = context.read<CategoryProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Category',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    if (expenseProvider.selectedCategoryId != null)
                      TextButton(
                        onPressed: () {
                          expenseProvider.setCategoryFilter(null);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (context, index) {
                      final cat = categoryProvider.categories[index];
                      final isSelected = expenseProvider.selectedCategoryId == cat.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGold.withValues(alpha: 0.15),
                          child: Icon(Icons.category_rounded, color: AppColors.primaryGold, size: 20),
                        ),
                        title: Text(cat.categoryName, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGold) : null,
                        onTap: () {
                          expenseProvider.setCategoryFilter(cat.id);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenseProvider = context.watch<ExpenseProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;

    final expenses = expenseProvider.filteredExpenses;
    final hasActiveFilters = expenseProvider.searchQuery.isNotEmpty ||
        expenseProvider.selectedCategoryId != null ||
        _selectedQuickPeriod != 'All' ||
        _selectedType != 'All';

    final totalFiltered = expenses.fold(0.0, (sum, e) => sum + (e.isIncome ? e.amount : -e.amount));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: expenseProvider.selectedCategoryId != null ? AppColors.primaryGold : null,
            ),
            tooltip: 'Filter by Category',
            onPressed: _openCategoryFilterModal,
          ),
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Clear Filters',
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                setState(() {
                  _selectedQuickPeriod = 'All';
                  _selectedType = 'All';
                });
                expenseProvider.clearFilters();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by category, remarks or note...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          expenseProvider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (val) {
                expenseProvider.setSearchQuery(val);
              },
            ),
          ),

          // Type Segmented Switcher: All | 🔥 Expense | 💰 Income
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: ['All', 'Expense', 'Income'].map((type) {
                  final isSelected = _selectedType == type;
                  Color activeColor;
                  if (type == 'Expense') {
                    activeColor = const Color(0xFFE11D48);
                  } else if (type == 'Income') {
                    activeColor = const Color(0xFF059669);
                  } else {
                    activeColor = AppColors.primaryGold;
                  }

                  return Expanded(
                    child: InkWell(
                      onTap: () => _onTypeSelected(type),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            type == 'Expense' ? '🔥 Expense' : (type == 'Income' ? '💰 Income' : 'All'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (type == 'All' ? AppColors.darkNavy : Colors.white)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Quick Period Chips: All | Today | This Week | This Month
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Today', 'This Week', 'This Month'].map((period) {
                final isSelected = _selectedQuickPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(period),
                    selected: isSelected,
                    selectedColor: AppColors.primaryGold.withValues(alpha: isDark ? 0.25 : 0.2),
                    checkmarkColor: AppColors.primaryGold,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? AppColors.primaryGoldLight : AppColors.primaryGoldDark)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryGold
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    onSelected: (_) => _onQuickPeriodSelected(period),
                  ),
                );
              }).toList(),
            ),
          ),

          // Count & Total header
          if (expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${expenses.length} transaction${expenses.length == 1 ? "" : "s"}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Net: ${CurrencyHelper.formatAmount(totalFiltered.abs(), symbol: currencySymbol)} ${totalFiltered >= 0 ? "(+)" : "(-)"}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: totalFiltered >= 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),

          // Transactions Feed
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 54,
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            hasActiveFilters ? 'No matching transactions found' : 'No transactions recorded yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveFilters
                                ? 'Try clearing or changing your filters'
                                : 'Shake your phone anytime to add an expense or income!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final cat = categoryProvider.categories.firstWhere(
                        (c) => c.categoryName == expense.categoryName,
                        orElse: () => categoryProvider.fallbackCategory,
                      );
                      return ExpenseCard(
                        expense: expense,
                        currencySymbol: currencySymbol,
                        categoryIcon: cat.icon,
                        categoryColorHex: cat.color,
                        onTap: () => ExpenseDetailsModal.show(context, expense),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
