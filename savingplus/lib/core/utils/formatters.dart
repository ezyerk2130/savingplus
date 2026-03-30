import 'package:intl/intl.dart';

String formatMoney(dynamic amount, {String currency = 'TZS'}) {
  double value = 0;
  if (amount is String) value = double.tryParse(amount) ?? 0;
  if (amount is num) value = amount.toDouble();
  final formatted = NumberFormat('#,##0.00', 'en').format(value);
  return '$currency $formatted';
}

String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(date);
  } catch (_) {
    return dateStr;
  }
}

String formatDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  } catch (_) {
    return dateStr;
  }
}
