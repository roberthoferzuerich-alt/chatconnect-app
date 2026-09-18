import 'dart:io';
import 'package:app/core/services/zego_service.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      final repo = ref.read(authRepositoryProvider);
      return AuthNotifier(repo, ref)..checkAuth();
    });

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AsyncValue.loading());

  Future<void> updateProfile({
    String? name,
    String? about,
    String? phone,
    File? avatar,
  }) async {
    try {
      final updatedUser = await _repository.updateProfile(
        name: name,
        about: about,
        phone: phone,
        avatar: avatar,
      );
      if (updatedUser != null) {
        state = AsyncValue.data(updatedUser);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkAuth() async {
    state = const AsyncValue.loading();
    try {
      final hasToken = await _repository.hasToken();
      if (hasToken) {
        final user = await _repository.me();
        if (user != null) {
          ZegoService.init(userID: user.id.toString(), userName: user.name);
          _ref.read(pushNotificationServiceProvider).init();
          state = AsyncValue.data(user);
        } else {
          state = const AsyncValue.data(null);
        }
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(email, password);
      if (user != null) {
        ZegoService.init(userID: user.id.toString(), userName: user.name);
        _ref.read(pushNotificationServiceProvider).init();
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register(
    String name,
    String email,
    String phone,
    String password, {
    File? avatar,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        name,
        email,
        phone,
        password,
        avatar: avatar,
      );
      if (user != null) {
        ZegoService.init(userID: user.id.toString(), userName: user.name);
        _ref.read(pushNotificationServiceProvider).init();
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    ZegoService.uninit();
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}
