import 'package:flutter_test/flutter_test.dart';
import 'package:savingplus/core/api/api_client.dart';

void main() {
  group('ApiClient.getErrorMessage', () {
    test('returns fallback for null', () {
      expect(ApiClient.getErrorMessage(null), 'Something went wrong');
    });

    test('returns custom fallback', () {
      expect(ApiClient.getErrorMessage(null, 'Custom error'), 'Custom error');
    });

    test('returns message from ApiException', () {
      final err = ApiException('Test error', statusCode: 400);
      expect(ApiClient.getErrorMessage(err), 'Test error');
    });

    test('returns fallback for unknown error type', () {
      expect(ApiClient.getErrorMessage(Exception('unknown')), 'Something went wrong');
    });

    test('ApiException toString returns message', () {
      final err = ApiException('Network error', statusCode: 500);
      expect(err.toString(), 'Network error');
      expect(err.message, 'Network error');
      expect(err.statusCode, 500);
    });

    test('ApiException without statusCode', () {
      final err = ApiException('Generic error');
      expect(err.statusCode, isNull);
      expect(err.message, 'Generic error');
    });
  });

  group('ApiConfig', () {
    test('baseUrl is not empty', () {
      expect(ApiConfig.baseUrl.isNotEmpty, true);
    });

    test('baseUrl contains /api/v1', () {
      expect(ApiConfig.baseUrl.contains('/api/v1'), true);
    });

    test('baseUrl starts with http', () {
      expect(ApiConfig.baseUrl.startsWith('http'), true);
    });

    test('baseUrl contains port 8080', () {
      expect(ApiConfig.baseUrl.contains('8080'), true);
    });
  });
}
