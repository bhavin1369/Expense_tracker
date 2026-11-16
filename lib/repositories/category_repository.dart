import '../database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper;

  CategoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<CategoryModel>> getAllCategories({bool activeOnly = true}) async {
    return await _dbHelper.getAllCategories(activeOnly: activeOnly);
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    return await _dbHelper.getCategoryById(id);
  }

  Future<int> addCategory(CategoryModel category) async {
    return await _dbHelper.insertCategory(category);
  }

  Future<int> updateCategory(CategoryModel category) async {
    return await _dbHelper.updateCategory(category);
  }

  Future<int> getCategoryExpenseCount(int categoryId) async {
    return await _dbHelper.getCategoryExpenseCount(categoryId);
  }

  Future<void> deleteCategory(
    int categoryId, {
    int? reassignToCategoryId,
    String? reassignToCategoryName,
  }) async {
    if (reassignToCategoryId != null && reassignToCategoryName != null) {
      await _dbHelper.reassignCategoryAndArchive(
        categoryId,
        reassignToCategoryId,
        reassignToCategoryName,
      );
    } else {
      final count = await _dbHelper.getCategoryExpenseCount(categoryId);
      if (count > 0) {
        // Safe archive so historical records keep their category link
        final category = await _dbHelper.getCategoryById(categoryId);
        if (category != null) {
          await _dbHelper.updateCategory(category.copyWith(isActive: false));
        }
      } else {
        await _dbHelper.deleteCategoryPermanently(categoryId);
      }
    }
  }

  Future<void> restoreDefaultCategories() async {
    await _dbHelper.restoreDefaultCategories();
  }
}
