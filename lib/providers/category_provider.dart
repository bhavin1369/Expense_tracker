import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryRepository _categoryRepository = CategoryRepository();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    _categories = await _categoryRepository.getAllCategories(activeOnly: true);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCategory({
    required String name,
    required String icon,
    required String color,
  }) async {
    final existing = _categories.any(
      (c) => c.categoryName.toLowerCase() == name.trim().toLowerCase(),
    );
    if (existing) {
      return false;
    }

    final newCategory = CategoryModel(
      categoryName: name.trim(),
      icon: icon,
      color: color,
      isDefault: false,
      isActive: true,
    );

    final id = await _categoryRepository.addCategory(newCategory);
    if (id > 0) {
      await loadCategories();
      return true;
    }
    return false;
  }

  Future<bool> updateCategory(CategoryModel category) async {
    final result = await _categoryRepository.updateCategory(category);
    if (result > 0) {
      await loadCategories();
      return true;
    }
    return false;
  }

  Future<int> getCategoryExpenseCount(int categoryId) async {
    return await _categoryRepository.getCategoryExpenseCount(categoryId);
  }

  Future<void> deleteCategory(
    int categoryId, {
    int? reassignToCategoryId,
    String? reassignToCategoryName,
  }) async {
    await _categoryRepository.deleteCategory(
      categoryId,
      reassignToCategoryId: reassignToCategoryId,
      reassignToCategoryName: reassignToCategoryName,
    );
    await loadCategories();
  }

  Future<void> restoreDefaults() async {
    await _categoryRepository.restoreDefaultCategories();
    await loadCategories();
  }

  CategoryModel? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CategoryModel get fallbackCategory {
    try {
      return _categories.firstWhere(
        (c) => c.categoryName.toLowerCase() == 'other',
      );
    } catch (_) {
      return _categories.isNotEmpty
          ? _categories.first
          : CategoryModel(
              id: 999,
              categoryName: 'Other',
              icon: 'more_horiz_rounded',
              color: '#78909C',
              isDefault: true,
            );
    }
  }
}
