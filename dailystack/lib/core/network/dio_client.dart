import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_response.dart';

class DioClient {
  final Dio dio;
  final FlutterSecureStorage storage;
  final VoidCallback? onSessionExpired;

  DioClient({
    FlutterSecureStorage? secureStorage,
    this.onSessionExpired,
  })  : storage = secureStorage ?? const FlutterSecureStorage(),
        dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(_AuthInterceptor(dio, storage, onSessionExpired));
  }

  static ApiException mapError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String? ?? 'Une erreur est survenue';
      final rawData = data['data'];
      return ApiException(
        message,
        statusCode: e.response?.statusCode,
        fieldErrors: rawData is Map<String, dynamic> ? rawData : null,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException('Connexion au serveur impossible. Vérifiez votre réseau.');
    }
    return ApiException('Erreur réseau inattendue', statusCode: e.response?.statusCode);
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final VoidCallback? _onSessionExpired;
  Completer<String?>? _refreshCompleter;

  _AuthInterceptor(this._dio, this._storage, this._onSessionExpired);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isAuthRoute = options.path.startsWith('/auth/');
    if (!isAuthRoute) {
      final token = await _storage.read(key: 'accessToken');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthRoute = err.requestOptions.path.startsWith('/auth/');
    if (err.response?.statusCode != 401 || isAuthRoute) {
      return handler.next(err);
    }

    if (_refreshCompleter != null) {
      final newToken = await _refreshCompleter!.future;
      if (newToken == null) {
        return handler.next(err);
      }
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      try {
        final retried = await _dio.fetch(err.requestOptions);
        return handler.resolve(retried);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken == null || refreshToken.isEmpty) {
        await _expireSession();
        completer.complete(null);
        return handler.next(err);
      }

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final newAccessToken = data['accessToken'] as String;
      await _storage.write(key: 'accessToken', value: newAccessToken);
      final newRefreshToken = data['refreshToken'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write(key: 'refreshToken', value: newRefreshToken);
      }

      completer.complete(newAccessToken);
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retried = await _dio.fetch(err.requestOptions);
      return handler.resolve(retried);
    } catch (_) {
      await _expireSession();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _expireSession() async {
    await _storage.deleteAll();
    _onSessionExpired?.call();
  }
}

