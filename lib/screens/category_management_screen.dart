import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import '../utils/constants.dart';
import '../utils/icon_helper.dart';
import '../widgets/add_category_dialog.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  void _showAddCategoryDialog(BuildContext context, [CategoryModel? toEdit]) {
    showDialog(
      context: context,
      builder: (ctx) => AddCategoryDialog(categoryToEdit: toEdit),
    );
  }

  Future<void> _handleDeleteCategory(BuildContext context, CategoryModel category) async {
    final provider = context.read<CategoryProvider>();
    final count = await provider.getCategoryExpenseCount(category.id!);

    if (!context.mounted) return;

    if (count > 0) {
      // Reassign dialog
      final otherCategories = provider.categories
          .where((c) => c.id != category.id)
          .toList();

      CategoryModel selectedReassign = provider.fallbackCategory;
      if (selectedReassign.id == category.id && otherCategories.isNotEmpty) {
        selectedReassign = otherCategories.first;
      }

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reassign Transactions'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'There are $count transactions under "${category.categoryName}".\n\nTo preserve your historical financial data, please select another category to reassign these transactions to:',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoryModel>(
                  initialValue: selectedReassign,
                  items: otherCategories.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.categoryName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReassign = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await provider.deleteCategory(
                    category.id!,
                    reassignToCategoryId: selectedReassign.id,
                    reassignToCategoryName: selectedReassign.categoryName,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Transactions reassigned to ${selectedReassign.categoryName} and category deleted.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Reassign & Delete'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Simple confirm dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Category?'),
          content: Text('Are you sure you want to delete "${category.categoryName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await provider.deleteCategory(category.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category deleted successfully')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _confirmRestoreDefaults(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Default Categories?'),
        content: const Text(
          'This will ensure all 27 default expense categories are active and reset to their default icons and colors. Your custom categories and transaction history will not be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<CategoryProvider>().restoreDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Default categories restored successfully!')),
                );
              }
            },
            child: const Text('Restore Defaults'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Restore Default Categories',
            onPressed: () => _confirmRestoreDefaults(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Custom Category',
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final color = IconHelper.parseColor(category.color);
          final iconData = IconHelper.getIcon(category.icon);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: color, size: 22),
              ),
              title: Text(
                category.categoryName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                category.isDefault ? 'Default Category' : 'Custom Category',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _showAddCategoryDialog(context, category),
                  ),
                  if (!category.isDefault)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.accentRed),
                      tooltip: 'Delete',
                      onPressed: () => _handleDeleteCategory(context, category),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: AppColors.primaryGold,
        foregroundColor: AppColors.darkNavy,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
