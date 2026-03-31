import 'package:flutter_test/flutter_test.dart';
import 'package:savingplus/core/utils/formatters.dart';

void main() {
  group('formatMoney', () {
    test('formats string amount', () {
      expect(formatMoney('1000'), 'TZS 1,000.00');
    });
    test('formats with decimal', () {
      expect(formatMoney('1234.56'), 'TZS 1,234.56');
    });
    test('formats zero', () {
      expect(formatMoney('0'), 'TZS 0.00');
    });
    test('formats with custom currency', () {
      expect(formatMoney('100', currency: 'USD'), 'USD 100.00');
    });
    test('handles empty string', () {
      expect(formatMoney(''), 'TZS 0.00');
    });
    test('formats numeric input', () {
      expect(formatMoney(5000), 'TZS 5,000.00');
    });
    test('formats large amount', () {
      expect(formatMoney('1000000'), 'TZS 1,000,000.00');
    });
    test('formats int input', () {
      expect(formatMoney(100), 'TZS 100.00');
    });
    test('formats double input', () {
      expect(formatMoney(99.99), 'TZS 99.99');
    });
    test('handles non-numeric string', () {
      expect(formatMoney('abc'), 'TZS 0.00');
    });
  });

  group('formatDate', () {
    test('formats ISO date', () {
      final result = formatDate('2026-03-30T14:30:00Z');
      expect(result, contains('Mar'));
      expect(result, contains('2026'));
      expect(result, contains('30'));
    });
    test('formats date-only string', () {
      final result = formatDate('2026-01-15');
      expect(result, contains('Jan'));
      expect(result, contains('15'));
      expect(result, contains('2026'));
    });
    test('handles empty string', () {
      expect(formatDate(''), '-');
    });
    test('handles null', () {
      expect(formatDate(null), '-');
    });
    test('returns original on unparseable input', () {
      expect(formatDate('not-a-date'), 'not-a-date');
    });
  });

  group('formatDateTime', () {
    test('formats ISO datetime with time', () {
      final result = formatDateTime('2026-03-30T14:30:00Z');
      expect(result, contains('Mar'));
      expect(result, contains('2026'));
    });
    test('handles empty string', () {
      expect(formatDateTime(''), '-');
    });
    test('handles null', () {
      expect(formatDateTime(null), '-');
    });
  });
}
