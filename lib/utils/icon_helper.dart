import 'package:flutter/material.dart';

class IconHelper {
  static const Map<String, IconData> iconMap = {
    'fastfood_rounded': Icons.fastfood_rounded,
    'directions_bus_rounded': Icons.directions_bus_rounded,
    'shopping_bag_rounded': Icons.shopping_bag_rounded,
    'local_grocery_store_rounded': Icons.local_grocery_store_rounded,
    'movie_rounded': Icons.movie_rounded,
    'receipt_long_rounded': Icons.receipt_long_rounded,
    'medical_services_rounded': Icons.medical_services_rounded,
    'school_rounded': Icons.school_rounded,
    'flight_takeoff_rounded': Icons.flight_takeoff_rounded,
    'spa_rounded': Icons.spa_rounded,
    'home_rounded': Icons.home_rounded,
    'local_gas_station_rounded': Icons.local_gas_station_rounded,
    'wifi_rounded': Icons.wifi_rounded,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'devices_rounded': Icons.devices_rounded,
    'card_giftcard_rounded': Icons.card_giftcard_rounded,
    'restaurant_rounded': Icons.restaurant_rounded,
    'subscriptions_rounded': Icons.subscriptions_rounded,
    'groups_rounded': Icons.groups_rounded,
    'pets_rounded': Icons.pets_rounded,
    'menu_book_rounded': Icons.menu_book_rounded,
    'night_shelter_rounded': Icons.night_shelter_rounded,
    'business_center_rounded': Icons.business_center_rounded,
    'two_wheeler_rounded': Icons.two_wheeler_rounded,
    'handyman_rounded': Icons.handyman_rounded,
    'local_shipping_rounded': Icons.local_shipping_rounded,
    'more_horiz_rounded': Icons.more_horiz_rounded,

    // Additional icons for custom categories
    'sports_esports_rounded': Icons.sports_esports_rounded,
    'music_note_rounded': Icons.music_note_rounded,
    'local_cafe_rounded': Icons.local_cafe_rounded,
    'work_rounded': Icons.work_rounded,
    'savings_rounded': Icons.savings_rounded,
    'account_balance_rounded': Icons.account_balance_rounded,
    'hotel_rounded': Icons.hotel_rounded,
    'child_friendly_rounded': Icons.child_friendly_rounded,
    'celebration_rounded': Icons.celebration_rounded,
    'computer_rounded': Icons.computer_rounded,
    'train_rounded': Icons.train_rounded,
    'brush_rounded': Icons.brush_rounded,
    'sports_soccer_rounded': Icons.sports_soccer_rounded,
    'construction_rounded': Icons.construction_rounded,
    'local_laundry_service_rounded': Icons.local_laundry_service_rounded,
    'kitchen_rounded': Icons.kitchen_rounded,
    'book_rounded': Icons.book_rounded,
    'camera_alt_rounded': Icons.camera_alt_rounded,
    'healing_rounded': Icons.healing_rounded,
    'star_rounded': Icons.star_rounded,
  };

  static IconData getIcon(String iconName) {
    return iconMap[iconName] ?? Icons.category_rounded;
  }

  static String getIconName(IconData icon) {
    for (final entry in iconMap.entries) {
      if (entry.value == icon) {
        return entry.key;
      }
    }
    return 'category_rounded';
  }

  static final List<String> availableIcons = iconMap.keys.toList();

  static final List<String> availableColors = [
    '#FF7043', // Deep Orange
    '#42A5F5', // Blue
    '#EC407A', // Pink
    '#66BB6A', // Green
    '#AB47BC', // Purple
    '#FFA726', // Orange
    '#EF5350', // Red
    '#26A69A', // Teal
    '#29B6F6', // Light Blue
    '#8D6E63', // Brown
    '#5C6BC0', // Indigo
    '#FFB300', // Amber
    '#26C6DA', // Cyan
    '#9CCC65', // Light Green
    '#7E57C2', // Deep Purple
    '#F06292', // Light Pink
    '#FF8A65', // Coral
    '#D4E157', // Lime
    '#3F51B5', // Indigo
    '#00897B', // Dark Teal
    '#546E7A', // Blue Grey
    '#3949AB', // Dark Indigo
    '#E65100', // Dark Orange
    '#6D4C41', // Dark Brown
    '#00ACC1', // Dark Cyan
    '#78909C', // Slate
    '#D4AF37', // Gold
    '#10B981', // Emerald
    '#06B6D4', // Cyan
    '#F43F5E', // Rose
    '#6366F1', // Indigo Accent
    '#84CC16', // Lime Accent
  ];

  static Color parseColor(String hexColor) {
    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFD4AF37);
    }
  }

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
