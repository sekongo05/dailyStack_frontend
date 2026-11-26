import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_database.dart';
import '../models/auth_models.dart';

class AuthService {
  final DioClient _client;
  final LocalDatabase? _localDb;

  // ignore: prefer_initializing_formals
  AuthService(this._client, {LocalDatabase? localDb}) : _localDb = localDb;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
    int initialLevel = 1,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'username': username,
          'initialLevel': initialLevel,
        },
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );
      final auth = apiRes.data!;
      await _saveTokens(auth);
      return auth;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => AuthResponse.fromJson(data as Map<String, dynamic>),
      );
      final auth = apiRes.data!;
      await _saveTokens(auth);
      return auth;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<UserProfile> getMe() async {
    try {
      final response = await _client.dio.get('/users/me');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => UserProfile.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<UserPreferences> getPreferences() async {
    try {
      final response = await _client.dio.get('/users/me/preferences');
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => UserPreferences.fromJson(data as Map<String, dynamic>),
      );
      final prefs = apiRes.data;
      if (prefs == null) {
        throw Exception('Préférences utilisateur indisponibles.');
      }
      return prefs;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<UserPreferences> updatePreferences(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.put('/users/me/preferences', data: payload);
      final apiRes = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => UserPreferences.fromJson(data as Map<String, dynamic>),
      );
      return apiRes.data!;
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _client.dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      final apiRes = ApiResponse<void>.fromJson(
        response.data as Map<String, dynamic>,
        null,
      );
      return apiRes.message ??
          'Si un compte existe avec cette adresse e-mail, un code de réinitialisation a été envoyé.';
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/reset-password',
        data: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
      );
      final apiRes = ApiResponse<void>.fromJson(
        response.data as Map<String, dynamic>,
        null,
      );
      return apiRes.message ?? 'Votre mot de passe a été réinitialisé avec succès.';
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  Future<void> logout() async {
    await _client.storage.deleteAll();
    await _localDb?.clearAll();
  }

  Future<bool> hasStoredSession() async {
    final token = await _client.storage.read(key: 'accessToken');
    return token != null && token.isNotEmpty;
  }

  Future<void> _saveTokens(AuthResponse auth) async {
    await _client.storage.write(key: 'accessToken', value: auth.accessToken);
    await _client.storage.write(key: 'refreshToken', value: auth.refreshToken);
  }
}

