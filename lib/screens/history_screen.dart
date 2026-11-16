import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _selectedQuickPeriod != 'All';

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
                setState(() => _selectedQuickPeriod = 'All');
                expenseProvider.clearFilters();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by category or note...',
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

          // Simple Quick Period Chips: All | Today | This Week | This Month
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      fontSize: 12.5,
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
          const SizedBox(height: 6),

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
                            hasActiveFilters
                                ? 'No matching expenses found'
                                : 'No expenses recorded yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveFilters
                                ? 'Try changing your search term or filter'
                                : 'Shake your phone anytime to add your first expense!',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
