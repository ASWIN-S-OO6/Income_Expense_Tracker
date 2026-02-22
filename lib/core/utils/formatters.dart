import 'package:intl/intl.dart';

class Formatters {
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return currencyFormatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }
}
