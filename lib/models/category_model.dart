class CategoryModel {
  final int? id;
  final String categoryName;
  final String icon;
  final String color;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    this.id,
    required this.categoryName,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'category_name': categoryName,
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
    String? icon,
    String? color,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<CategoryModel> get defaultCategories => [
        CategoryModel(categoryName: 'Food & Drinks', icon: 'fastfood_rounded', color: '#FF7043', isDefault: true),
        CategoryModel(categoryName: 'Transportation', icon: 'directions_bus_rounded', color: '#42A5F5', isDefault: true),
        CategoryModel(categoryName: 'Shopping', icon: 'shopping_bag_rounded', color: '#EC407A', isDefault: true),
        CategoryModel(categoryName: 'Groceries', icon: 'local_grocery_store_rounded', color: '#66BB6A', isDefault: true),
        CategoryModel(categoryName: 'Entertainment', icon: 'movie_rounded', color: '#AB47BC', isDefault: true),
        CategoryModel(categoryName: 'Bills & Utilities', icon: 'receipt_long_rounded', color: '#FFA726', isDefault: true),
        CategoryModel(categoryName: 'Health & Medical', icon: 'medical_services_rounded', color: '#EF5350', isDefault: true),
        CategoryModel(categoryName: 'Education', icon: 'school_rounded', color: '#26A69A', isDefault: true),
        CategoryModel(categoryName: 'Travel', icon: 'flight_takeoff_rounded', color: '#29B6F6', isDefault: true),
        CategoryModel(categoryName: 'Personal Care', icon: 'spa_rounded', color: '#8D6E63', isDefault: true),
        CategoryModel(categoryName: 'Rent & Housing', icon: 'home_rounded', color: '#5C6BC0', isDefault: true),
        CategoryModel(categoryName: 'Fuel', icon: 'local_gas_station_rounded', color: '#FFB300', isDefault: true),
        CategoryModel(categoryName: 'Mobile & Internet', icon: 'wifi_rounded', color: '#26C6DA', isDefault: true),
        CategoryModel(categoryName: 'Sports & Fitness', icon: 'fitness_center_rounded', color: '#9CCC65', isDefault: true),
        CategoryModel(categoryName: 'Electronics', icon: 'devices_rounded', color: '#7E57C2', isDefault: true),
        CategoryModel(categoryName: 'Gifts & Donations', icon: 'card_giftcard_rounded', color: '#F06292', isDefault: true),
        CategoryModel(categoryName: 'Restaurants & Cafes', icon: 'restaurant_rounded', color: '#FF8A65', isDefault: true),
        CategoryModel(categoryName: 'Subscriptions', icon: 'subscriptions_rounded', color: '#D4E157', isDefault: true),
        CategoryModel(categoryName: 'Family', icon: 'groups_rounded', color: '#3F51B5', isDefault: true),
        CategoryModel(categoryName: 'Pets', icon: 'pets_rounded', color: '#8D6E63', isDefault: true),
        CategoryModel(categoryName: 'College Expenses', icon: 'menu_book_rounded', color: '#00897B', isDefault: true),
        CategoryModel(categoryName: 'Hostel Expenses', icon: 'night_shelter_rounded', color: '#546E7A', isDefault: true),
        CategoryModel(categoryName: 'Office Expenses', icon: 'business_center_rounded', color: '#3949AB', isDefault: true),
        CategoryModel(categoryName: 'Bike Maintenance', icon: 'two_wheeler_rounded', color: '#E65100', isDefault: true),
        CategoryModel(categoryName: 'Home Maintenance', icon: 'handyman_rounded', color: '#6D4C41', isDefault: true),
        CategoryModel(categoryName: 'Online Orders', icon: 'local_shipping_rounded', color: '#00ACC1', isDefault: true),
        CategoryModel(categoryName: 'Other', icon: 'more_horiz_rounded', color: '#78909C', isDefault: true),
      ];
}
