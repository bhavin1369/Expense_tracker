class CategoryModel {
  final int? id;
  final String categoryName;
  final String categoryType; // 'expense' or 'income'
  final String icon;
  final String color;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    this.id,
    required this.categoryName,
    this.categoryType = 'expense',
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isIncome => categoryType.toLowerCase() == 'income';
  bool get isExpense => !isIncome;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'category_name': categoryName,
      'category_type': categoryType,
      'icon': icon,
      'color': color,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      categoryName: map['category_name'] as String,
      categoryType: map['category_type'] as String? ?? 'expense',
      icon: map['icon'] as String,
      color: map['color'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  CategoryModel copyWith({
    int? id,
    String? categoryName,
    String? categoryType,
    String? icon,
    String? color,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      categoryType: categoryType ?? this.categoryType,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<CategoryModel> get defaultExpenseCategories => [
        CategoryModel(categoryName: 'Food & Drinks', categoryType: 'expense', icon: 'fastfood_rounded', color: '#FF7043', isDefault: true),
        CategoryModel(categoryName: 'Transportation', categoryType: 'expense', icon: 'directions_bus_rounded', color: '#42A5F5', isDefault: true),
        CategoryModel(categoryName: 'Shopping', categoryType: 'expense', icon: 'shopping_bag_rounded', color: '#EC407A', isDefault: true),
        CategoryModel(categoryName: 'Groceries', categoryType: 'expense', icon: 'local_grocery_store_rounded', color: '#66BB6A', isDefault: true),
        CategoryModel(categoryName: 'Entertainment', categoryType: 'expense', icon: 'movie_rounded', color: '#AB47BC', isDefault: true),
        CategoryModel(categoryName: 'Bills & Utilities', categoryType: 'expense', icon: 'receipt_long_rounded', color: '#FFA726', isDefault: true),
        CategoryModel(categoryName: 'Health & Medical', categoryType: 'expense', icon: 'medical_services_rounded', color: '#EF5350', isDefault: true),
        CategoryModel(categoryName: 'Education', categoryType: 'expense', icon: 'school_rounded', color: '#26A69A', isDefault: true),
        CategoryModel(categoryName: 'Travel', categoryType: 'expense', icon: 'flight_takeoff_rounded', color: '#29B6F6', isDefault: true),
        CategoryModel(categoryName: 'Personal Care', categoryType: 'expense', icon: 'spa_rounded', color: '#8D6E63', isDefault: true),
        CategoryModel(categoryName: 'Rent & Housing', categoryType: 'expense', icon: 'home_rounded', color: '#5C6BC0', isDefault: true),
        CategoryModel(categoryName: 'Fuel', categoryType: 'expense', icon: 'local_gas_station_rounded', color: '#FFB300', isDefault: true),
        CategoryModel(categoryName: 'Mobile & Internet', categoryType: 'expense', icon: 'wifi_rounded', color: '#26C6DA', isDefault: true),
        CategoryModel(categoryName: 'Sports & Fitness', categoryType: 'expense', icon: 'fitness_center_rounded', color: '#9CCC65', isDefault: true),
        CategoryModel(categoryName: 'Electronics', categoryType: 'expense', icon: 'devices_rounded', color: '#7E57C2', isDefault: true),
        CategoryModel(categoryName: 'Gifts & Donations', categoryType: 'expense', icon: 'card_giftcard_rounded', color: '#F06292', isDefault: true),
        CategoryModel(categoryName: 'Restaurants & Cafes', categoryType: 'expense', icon: 'restaurant_rounded', color: '#FF8A65', isDefault: true),
        CategoryModel(categoryName: 'Subscriptions', categoryType: 'expense', icon: 'subscriptions_rounded', color: '#D4E157', isDefault: true),
        CategoryModel(categoryName: 'Family', categoryType: 'expense', icon: 'groups_rounded', color: '#3F51B5', isDefault: true),
        CategoryModel(categoryName: 'Pets', categoryType: 'expense', icon: 'pets_rounded', color: '#8D6E63', isDefault: true),
        CategoryModel(categoryName: 'College Expenses', categoryType: 'expense', icon: 'menu_book_rounded', color: '#00897B', isDefault: true),
        CategoryModel(categoryName: 'Hostel Expenses', categoryType: 'expense', icon: 'night_shelter_rounded', color: '#546E7A', isDefault: true),
        CategoryModel(categoryName: 'Office Expenses', categoryType: 'expense', icon: 'business_center_rounded', color: '#3949AB', isDefault: true),
        CategoryModel(categoryName: 'Bike Maintenance', categoryType: 'expense', icon: 'two_wheeler_rounded', color: '#E65100', isDefault: true),
        CategoryModel(categoryName: 'Home Maintenance', categoryType: 'expense', icon: 'handyman_rounded', color: '#6D4C41', isDefault: true),
        CategoryModel(categoryName: 'Online Orders', categoryType: 'expense', icon: 'local_shipping_rounded', color: '#00ACC1', isDefault: true),
        CategoryModel(categoryName: 'Other', categoryType: 'expense', icon: 'more_horiz_rounded', color: '#78909C', isDefault: true),
      ];

  static List<CategoryModel> get defaultIncomeCategories => [
        CategoryModel(categoryName: 'Salary', categoryType: 'income', icon: 'work_rounded', color: '#4CAF50', isDefault: true),
        CategoryModel(categoryName: 'Business Income', categoryType: 'income', icon: 'store_rounded', color: '#2196F3', isDefault: true),
        CategoryModel(categoryName: 'Freelance', categoryType: 'income', icon: 'laptop_mac_rounded', color: '#9C27B0', isDefault: true),
        CategoryModel(categoryName: 'Content Creation', categoryType: 'income', icon: 'videocam_rounded', color: '#E91E63', isDefault: true),
        CategoryModel(categoryName: 'Investments', categoryType: 'income', icon: 'trending_up_rounded', color: '#009688', isDefault: true),
        CategoryModel(categoryName: 'Interest & Dividends', categoryType: 'income', icon: 'account_balance_rounded', color: '#FF9800', isDefault: true),
        CategoryModel(categoryName: 'Rental Income', categoryType: 'income', icon: 'real_estate_agent_rounded', color: '#3F51B5', isDefault: true),
        CategoryModel(categoryName: 'Commission & Incentives', categoryType: 'income', icon: 'handshake_rounded', color: '#00BCD4', isDefault: true),
        CategoryModel(categoryName: 'Pension', categoryType: 'income', icon: 'elderly_rounded', color: '#795548', isDefault: true),
        CategoryModel(categoryName: 'Other Income', categoryType: 'income', icon: 'savings_rounded', color: '#607D8B', isDefault: true),
      ];

  static List<CategoryModel> get defaultCategories => [
        ...defaultExpenseCategories,
        ...defaultIncomeCategories,
      ];
}
