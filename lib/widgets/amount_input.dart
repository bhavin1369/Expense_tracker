import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class AmountInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final ValueChanged<double>? onAmountChanged;

  const AmountInputWidget({
    super.key,
    required this.controller,
    required this.currencySymbol,
    this.onAmountChanged,
  });

  void _addQuickAmount(double quickAdd) {
    HapticFeedback.lightImpact();
    final current = double.tryParse(controller.text) ?? 0.0;
    final updated = current + quickAdd;
    if (updated % 1 == 0) {
      controller.text = updated.toInt().toString();
    } else {
      controller.text = updated.toStringAsFixed(2);
    }
    onAmountChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                'ENTER EXPENSE AMOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencySymbol,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: IntrinsicWidth(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
                          onAmountChanged?.call(parsed);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick add chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickChip(50),
              _buildQuickChip(100),
              _buildQuickChip(200),
              _buildQuickChip(500),
              _buildQuickChip(1000),
              _buildQuickChip(2000),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(double amount) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text('+$currencySymbol${amount.toInt()}'),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.primaryGoldLight : AppColors.primaryGoldDark,
          ),
          backgroundColor: isDark
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : AppColors.primaryGold.withValues(alpha: 0.12),
          side: BorderSide(
            color: AppColors.primaryGold.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onPressed: () => _addQuickAmount(amount),
        ),
      );
    });
  }
}
