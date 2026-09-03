import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(apiClientProvider);
  return AuthRepository(dio: dio);
});

class AuthRepository {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  AuthRepository({required Dio dio}) : _dio = dio;

  Future<User?> updateProfile({
    String? name,
    String? about,
    File? avatar,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (name != null) 'name': name,
        if (about != null) 'about': about,
        if (avatar != null) 'avatar': await MultipartFile.fromFile(avatar.path),
      });

      final response = await _dio.post('auth/profile', data: formData);
      return User.fromJson(response.data['user']);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        'auth/login',
        data: {
          'email': email,
          'password': password,
          'device_name': 'mobile_app',
        },
      );

      final token = response.data['data']['token'];
      await _storage.write(key: 'auth_token', value: token);

      return User.fromJson(response.data['data']['user']);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> register(String name, String email, String password) async {
    try {
      final response = await _dio.post(
        'auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );

      final token = response.data['data']['token'];
      await _storage.write(key: 'auth_token', value: token);

      return User.fromJson(response.data['data']['user']);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('auth/logout');
    } catch (e) {
      // Fehler beim Logout ignorieren (z.B. wenn kein Internet)
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<User?> me() async {
    try {
      final response = await _dio.get('auth/me');
      return User.fromJson(response.data['data']);
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }
}
