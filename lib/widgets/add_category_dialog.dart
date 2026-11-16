import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import '../utils/constants.dart';
import '../utils/icon_helper.dart';

class AddCategoryDialog extends StatefulWidget {
  final CategoryModel? categoryToEdit;

  const AddCategoryDialog({super.key, this.categoryToEdit});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.categoryToEdit?.categoryName ?? '');
    _selectedIcon = widget.categoryToEdit?.icon ?? IconHelper.availableIcons.first;
    _selectedColor = widget.categoryToEdit?.color ?? IconHelper.availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CategoryProvider>();
    final isEditing = widget.categoryToEdit != null;

    if (isEditing) {
      final updated = widget.categoryToEdit!.copyWith(
        categoryName: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
      );
      await provider.updateCategory(updated);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      final success = await provider.addCategory(
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
      );
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A category with this name already exists.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.categoryToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Category' : 'New Custom Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Gaming, Office Lunch',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Icon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: IconHelper.availableIcons.length,
                    itemBuilder: (context, index) {
                      final iconKey = IconHelper.availableIcons[index];
                      final isSelected = _selectedIcon == iconKey;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedIcon = iconKey),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryGold.withValues(alpha: 0.2)
                                  : (isDark ? AppColors.darkCard : AppColors.lightBg),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              IconHelper.getIcon(iconKey),
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Color',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: IconHelper.availableColors.length,
                    itemBuilder: (context, index) {
                      final colorHex = IconHelper.availableColors[index];
                      final color = IconHelper.parseColor(colorHex);
                      final isSelected = _selectedColor == colorHex;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedColor = colorHex),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Create Category'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
