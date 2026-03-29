import 'package:intl/intl.dart';

String formatMoney(String amount, {String currency = 'TZS'}) {
  final num = double.tryParse(amount) ?? 0;
  final formatted = NumberFormat('#,##0.00', 'en_US').format(num);
  return '$currency $formatted';
}

String formatDate(String dateStr) {
  final date = DateTime.parse(dateStr);
  return DateFormat('MMM dd, yyyy').format(date);
}

String formatDateTime(String dateStr) {
  final date = DateTime.parse(dateStr);
  return DateFormat('MMM dd, yyyy HH:mm').format(date);
}

String formatPhone(String phone) {
  if (phone.startsWith('+255') && phone.length == 13) {
    return '+255 ${phone.substring(4, 7)} ${phone.substring(7, 10)} ${phone.substring(10)}';
  }
  return phone;
}
