import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiConfig {
  static String baseUrl = 'http://10.0.2.2:8080/api/v1';
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RateLimitException extends ApiException {
  RateLimitException() : super('Too many requests. Please wait a moment.');
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();
  bool _isRefreshing = false;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          _isRefreshing = false;
          // Retry the original request with new token
          final token = await _tokenStorage.getAccessToken();
          error.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await _dio.fetch(error.requestOptions);
          return handler.resolve(response);
        }
      } catch (_) {
        // Refresh failed, clear tokens
        await _tokenStorage.clearTokens();
      }
      _isRefreshing = false;
    }

    if (error.response?.statusCode == 429) {
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: RateLimitException(),
          response: error.response,
          type: DioExceptionType.badResponse,
        ),
      );
    }

    final data = error.response?.data;
    String message = 'An unexpected error occurred';
    if (data is Map<String, dynamic>) {
      message = data['detail'] ?? data['error'] ?? message;
    }

    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        error: ApiException(message, statusCode: error.response?.statusCode),
        response: error.response,
        type: error.type,
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});

      final data = response.data;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete(path, data: data, queryParameters: queryParameters);
  }
}
