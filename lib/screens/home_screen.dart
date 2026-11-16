import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/shake_detection_service.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/dashboard_summary_card.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_details_modal.dart';
import '../widgets/expense_entry_sheet.dart';
import 'excel_management_screen.dart';
import 'main_navigation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final userName = settingsProvider.userName;
    final currencySymbol = settingsProvider.currencySymbol;
    final greeting = AppDateUtils.getGreeting(userName);
    final currentDateFormatted = AppDateUtils.formatFullDate(DateTime.now());

    final monthlyData = expenseProvider.getLast6MonthsSpending();
    final recentExpenses = expenseProvider.recentExpenses;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              expenseProvider.loadExpenses(),
              categoryProvider.loadCategories(),
            ]);
          },
          color: AppColors.primaryGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Greeting, Date & Quick Shake Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentDateFormatted,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Shake test / simulation icon
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.vibration_rounded,
                          color: AppColors.primaryGold,
                          size: 20,
                        ),
                      ),
                      tooltip: 'Shake Phone or Tap to Add',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ShakeDetectionService.instance.simulateShake();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main Card: Total Expenses This Month & Today's Expenses
                DashboardSummaryCard(
                  todayTotal: expenseProvider.todayTotal,
                  thisMonthTotal: expenseProvider.thisMonthTotal,
                  currencySymbol: currencySymbol,
                  thisWeekTotal: expenseProvider.thisWeekTotal,
                  thisYearTotal: expenseProvider.thisYearTotal,
                  totalTransactions: expenseProvider.totalTransactionsCount,
                ),
                const SizedBox(height: 20),

                // Quick Actions (4 Clean Rounded Buttons)
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionItem(
                        context: context,
                        icon: Icons.add_circle_rounded,
                        label: 'Add Expense',
                        iconColor: AppColors.primaryGold,
                        bgColor: AppColors.primaryGold.withValues(alpha: 0.15),
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ExpenseEntrySheet.show(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionItem(
                        context: context,
                        icon: Icons.receipt_long_rounded,
                        label: 'View History',
                        iconColor: AppColors.accentBlue,
                        bgColor: AppColors.accentBlue.withValues(alpha: 0.15),
                        isDark: isDark,
                        onTap: () {
                          MainNavigationScreen.switchToTab(context, 1);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionItem(
                        context: context,
                        icon: Icons.bar_chart_rounded,
                        label: 'View Analytics',
                        iconColor: AppColors.accentPurple,
                        bgColor: AppColors.accentPurple.withValues(alpha: 0.15),
                        isDark: isDark,
                        onTap: () {
                          MainNavigationScreen.switchToTab(context, 2);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionItem(
                        context: context,
                        icon: Icons.table_chart_rounded,
                        label: 'Excel File',
                        iconColor: AppColors.accentGreen,
                        bgColor: AppColors.accentGreen.withValues(alpha: 0.15),
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExcelManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent Expenses Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (expenseProvider.allExpenses.isNotEmpty)
                      TextButton(
                        onPressed: () => MainNavigationScreen.switchToTab(context, 1),
                        child: const Row(
                          children: [
                            Text('View All', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (recentExpenses.isEmpty)
                  Card(
                    elevation: 0,
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 42,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No expenses added yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Shake your phone or tap Add Expense above!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = recentExpenses[index];
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
                const SizedBox(height: 24),

                // Simple Monthly Spending Chart Section
                Text(
                  'Monthly Spending Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: MonthlyBarChartWidget(
                      monthlyData: monthlyData,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
