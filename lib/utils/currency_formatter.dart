import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

class CurrencyHelper {
  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee (INR)'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar (USD)'),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro (EUR)'),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound (GBP)'),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen (JPY)'),
    CurrencyInfo(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar (CAD)'),
    CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar (AUD)'),
    CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham (AED)'),
    CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar (SGD)'),
  ];

  static String formatAmount(double amount, {String symbol = '₹', int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String symbol = '₹'}) {
    if (amount >= 10000000) {
      return '$symbol ${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '$symbol ${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '$symbol ${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$symbol ${amount.toStringAsFixed(0)}';
  }

  static CurrencyInfo getCurrencyInfo(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => const CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee (INR)'),
    );
  }
}
