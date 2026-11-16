import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';

class DashboardSummaryCard extends StatelessWidget {
  final double todayTotal;
  final double thisMonthTotal;
  final String currencySymbol;
  // Optional parameters for compatibility
  final double thisWeekTotal;
  final double thisYearTotal;
  final int totalTransactions;

  const DashboardSummaryCard({
    super.key,
    required this.todayTotal,
    required this.thisMonthTotal,
    required this.currencySymbol,
    this.thisWeekTotal = 0.0,
    this.thisYearTotal = 0.0,
    this.totalTransactions = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF162544),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gold icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primaryGold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    "THIS MONTH'S EXPENSES",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              if (totalTransactions > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalTransactions Txns',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Large prominent monthly total
          Text(
            CurrencyHelper.formatAmount(thisMonthTotal, symbol: currencySymbol),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),

          // Today's Expenses sub-card / pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.today_rounded,
                      size: 16,
                      color: AppColors.primaryGold,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Today's Expenses",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyHelper.formatAmount(todayTotal, symbol: currencySymbol),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
