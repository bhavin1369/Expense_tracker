import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/icon_helper.dart';
import '../widgets/chart_widgets.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenseProvider = context.watch<ExpenseProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;

    final monthlyData = expenseProvider.getLast6MonthsSpending();
    final weeklyData = expenseProvider.getCurrentWeekDailySpending();
    final categorySpendings = expenseProvider.getCategoryWiseSpending(categoryProvider.categories);

    final currentMonthTotal = expenseProvider.thisMonthTotal;
    final previousMonthTotal = expenseProvider.previousMonthTotal;
    final percentageChange = expenseProvider.monthOverMonthPercentageChange;
    final isIncrease = percentageChange > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Spending Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month-over-Month Comparison Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161F30), const Color(0xFF1E293B)]
                      : [Colors.white, const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MONTHLY COMPARISON',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isIncrease ? AppColors.accentRed : AppColors.accentGreen)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 13,
                              color: isIncrease ? AppColors.accentRed : AppColors.accentGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${percentageChange.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isIncrease ? AppColors.accentRed : AppColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This Month',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyHelper.formatAmount(currentMonthTotal, symbol: currencySymbol),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Month',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyHelper.formatAmount(previousMonthTotal, symbol: currencySymbol),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Monthly Expense Bar Chart
            _buildSectionTitle('Monthly Expense Trend (6 Months)', isDark),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MonthlyBarChartWidget(
                  monthlyData: monthlyData,
                  currencySymbol: currencySymbol,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Weekly Spending Line Chart
            _buildSectionTitle('This Week (Mon - Sun)', isDark),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: WeeklyLineChartWidget(
                  dailyData: weeklyData,
                  currencySymbol: currencySymbol,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Category-Wise Pie Chart
            _buildSectionTitle('Category-Wise Distribution', isDark),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CategoryPieChartWidget(
                  categorySpendings: categorySpendings,
                  currencySymbol: currencySymbol,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Category Ranking Breakdown List
            _buildSectionTitle('Category Spending Breakdown', isDark),
            const SizedBox(height: 12),
            if (categorySpendings.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No expense records found',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categorySpendings.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = categorySpendings[index];
                    final color = IconHelper.parseColor(item.colorHex);
                    final iconData = IconHelper.getIcon(item.icon);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, size: 18, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.categoryName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${item.count} transactions (${item.percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyHelper.formatAmount(item.totalAmount, symbol: currencySymbol),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Percentage progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: item.percentage / 100,
                              minHeight: 5,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }
}
