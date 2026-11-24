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

  static String userMessage(Object? error) {
    if (error is DioException) {
      return mapError(error).message;
    }
    return userFriendlyError(error);
  }

  static ApiException mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'] as String?;
      final rawData = data['data'];
      return ApiException(
        sanitizeErrorMessage(rawMessage),
        statusCode: statusCode,
        fieldErrors: rawData is Map<String, dynamic> ? rawData : null,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        'Connexion au serveur impossible. Vérifiez votre connexion internet et réessayez.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 401) {
      return ApiException(
        'Votre session a expiré. Veuillez vous reconnecter.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return ApiException(
        'Vous n\'avez pas les autorisations nécessaires pour effectuer cette action.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return ApiException(
        'L\'élément demandé est introuvable ou n\'est plus disponible.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return ApiException(
        'Trop de tentatives en peu de temps. Veuillez patienter un instant.',
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        'Le service est momentanément indisponible. Veuillez réessayer dans quelques instants.',
        statusCode: statusCode,
      );
    }
    return ApiException(
      'Impossible de communiquer avec le serveur. Veuillez réessayer.',
      statusCode: statusCode,
    );
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

