import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _compactFormat = NumberFormat.compact();
final _dateFormat = DateFormat('MMM d, yyyy');

String formatCurrency(num value) => _currencyFormat.format(value);
String formatCompactNumber(num value) => _compactFormat.format(value);
String formatDate(DateTime date) => _dateFormat.format(date);
String formatPercent(num value, {int decimals = 1}) => '${value.toStringAsFixed(decimals)}%';
