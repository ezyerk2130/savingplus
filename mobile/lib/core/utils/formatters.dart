import 'package:intl/intl.dart';

String formatMoney(String amount, {String currency = 'TZS'}) {
  final num = double.tryParse(amount) ?? 0;
  final formatted = NumberFormat('#,##0.00', 'en_US').format(num);
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

String formatPhone(String phone) {
  if (phone.startsWith('+255') && phone.length == 13) {
    return '+255 ${phone.substring(4, 7)} ${phone.substring(7, 10)} ${phone.substring(10)}';
  }
  return phone;
}
