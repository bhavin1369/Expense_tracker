import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/icon_helper.dart';

class MonthlyBarChartWidget extends StatelessWidget {
  final List<MonthlySpending> monthlyData;
  final String currencySymbol;

  const MonthlyBarChartWidget({
    super.key,
    required this.monthlyData,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxVal = 0;
    for (final m in monthlyData) {
      if (m.totalAmount > maxVal) maxVal = m.totalAmount;
    }
    if (maxVal == 0) maxVal = 100;

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final month = monthlyData[group.x.toInt()];
                return BarTooltipItem(
                  '${month.monthLabel}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: CurrencyHelper.formatAmount(rod.toY, symbol: currencySymbol),
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (val, meta) {
                  if (val == 0 || val == maxVal || val == (maxVal / 2).roundToDouble()) {
                    return Text(
                      CurrencyHelper.formatCompact(val, symbol: currencySymbol),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();
                  if (index >= 0 && index < monthlyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        monthlyData[index].monthLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(monthlyData.length, (i) {
            final isHighest = monthlyData[i].totalAmount == maxVal && maxVal > 0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthlyData[i].totalAmount,
                  gradient: LinearGradient(
                    colors: isHighest
                        ? [AppColors.primaryGold, const Color(0xFFE5A93C)]
                        : [
                            isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                            isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class CategoryPieChartWidget extends StatefulWidget {
  final List<CategorySpending> categorySpendings;
  final String currencySymbol;

  const CategoryPieChartWidget({
    super.key,
    required this.categorySpendings,
    required this.currencySymbol,
  });

  @override
  State<CategoryPieChartWidget> createState() => _CategoryPieChartWidgetState();
}

class _CategoryPieChartWidgetState extends State<CategoryPieChartWidget> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.categorySpendings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No expenses recorded yet',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      );
    }

    final topCategories = widget.categorySpendings.take(5).toList();

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: List.generate(topCategories.length, (i) {
                final isTouched = i == _touchedIndex;
                final cat = topCategories[i];
                final color = IconHelper.parseColor(cat.colorHex);
                final radius = isTouched ? 55.0 : 45.0;

                return PieChartSectionData(
                  color: color,
                  value: cat.totalAmount,
                  title: '${cat.percentage.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: topCategories.map((cat) {
            final color = IconHelper.parseColor(cat.colorHex);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '${cat.categoryName} (${cat.percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class WeeklyLineChartWidget extends StatelessWidget {
  final List<DailySpending> dailyData;
  final String currencySymbol;

  const WeeklyLineChartWidget({
    super.key,
    required this.dailyData,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxVal = 0;
    for (final d in dailyData) {
      if (d.totalAmount > maxVal) maxVal = d.totalAmount;
    }
    if (maxVal == 0) maxVal = 100;

    final spots = List.generate(
      dailyData.length,
      (i) => FlSpot(i.toDouble(), dailyData[i].totalAmount),
    );

    return AspectRatio(
      aspectRatio: 1.8,
      child: LineChart(
        LineChartData(
          maxY: maxVal * 1.25,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 3,
            getDrawingHorizontalLine: (val) => FlLine(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (val, meta) {
                  if (val == 0 || val == maxVal || val == (maxVal / 2).roundToDouble()) {
                    return Text(
                      CurrencyHelper.formatCompact(val, symbol: currencySymbol),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();
                  if (index >= 0 && index < dailyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dailyData[index].dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              barWidth: 3.5,
              isStrokeCapRound: true,
              gradient: const LinearGradient(
                colors: [AppColors.primaryGold, Color(0xFF10B981)],
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.3),
                    AppColors.primaryGold.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
