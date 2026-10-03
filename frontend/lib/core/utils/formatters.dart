import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _compactFormat = NumberFormat.compact();
final _dateFormat = DateFormat('MMM d, yyyy');

String formatCurrency(num value) => _currencyFormat.format(value);
String formatCompactNumber(num value) => _compactFormat.format(value);
String formatDate(DateTime date) => _dateFormat.format(date);
String formatPercent(num value, {int decimals = 1}) => '${value.toStringAsFixed(decimals)}%';

final _inrFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Indian-rupee amount with lakh grouping, e.g. ₹1,25,000.00
String formatInr(num value) => _inrFormat.format(value);
