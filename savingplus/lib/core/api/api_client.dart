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

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 429) {
          handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: ApiException('Too many requests. Please wait a moment.', statusCode: 429),
          ));
          return;
        }
        if (error.response?.statusCode == 401 && !error.requestOptions.extra.containsKey('retried')) {
          try {
            final refreshToken = await _tokenStorage.getRefreshToken();
            if (refreshToken != null) {
              final res = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
                  .post('/auth/refresh', data: {'refresh_token': refreshToken});
              await _tokenStorage.saveTokens(
                res.data['access_token'],
                res.data['refresh_token'],
              );
              error.requestOptions.extra['retried'] = true;
              error.requestOptions.headers['Authorization'] = 'Bearer ${res.data['access_token']}';
              final retry = await _dio.fetch(error.requestOptions);
              handler.resolve(retry);
              return;
            }
          } catch (_) {
            await _tokenStorage.clearTokens();
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  static String getErrorMessage(dynamic error, [String fallback = 'Something went wrong']) {
    if (error is DioException) {
      if (error.error is ApiException) return (error.error as ApiException).message;
      final data = error.response?.data;
      if (data is Map) return data['detail'] ?? data['error'] ?? fallback;
    }
    if (error is ApiException) return error.message;
    return fallback;
  }
}
