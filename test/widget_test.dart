import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/widgets/category_card.dart';
import 'package:expense_tracker/widgets/dashboard_summary_card.dart';

void main() {
  testWidgets('DashboardSummaryCard renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSummaryCard(
            todayTotal: 250.0,
            thisWeekTotal: 1200.0,
            thisMonthTotal: 4500.0,
            thisYearTotal: 50000.0,
            totalTransactions: 15,
            currencySymbol: '₹',
          ),
        ),
      ),
    );

    expect(find.text("THIS MONTH'S EXPENSES"), findsOneWidget);
    expect(find.text('15 Txns'), findsOneWidget);
    expect(find.text("Today's Expenses"), findsOneWidget);
  });

  testWidgets('CategoryCard renders and responds to tap', (WidgetTester tester) async {
    bool tapped = false;
    final cat = CategoryModel(
      id: 1,
      categoryName: 'Food & Drinks',
      icon: 'fastfood_rounded',
      color: '#FF7043',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryCard(
            category: cat,
            isSelected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Food & Drinks'), findsOneWidget);
    await tester.tap(find.byType(CategoryCard));
    expect(tapped, isTrue);
  });
}
