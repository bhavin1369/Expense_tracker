import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';
import '../utils/icon_helper.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = IconHelper.parseColor(category.color);
    final iconData = IconHelper.getIcon(category.icon);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGold.withValues(alpha: isDark ? 0.22 : 0.14)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGold
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGold.withValues(alpha: 0.25)
                      : categoryColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: isSelected ? AppColors.primaryGoldDark : categoryColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 7),

              // Short Category Name
              Text(
                category.categoryName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? AppColors.primaryGoldLight : AppColors.primaryGoldDark)
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
