import 'package:intl/intl.dart';

class AppDateUtils {
  static String getGreeting(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good Evening';
    } else {
      greeting = 'Good Night';
    }
    return '$greeting, $userName!';
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == yesterday) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('EEE, d MMM').format(date);
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDisplayTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    // Monday as start of week
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return (date.isAfter(startOfWeek) || isSameDay(date, startOfWeek)) && date.isBefore(endOfWeek);
  }

  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  static bool isThisYear(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year;
  }
}
