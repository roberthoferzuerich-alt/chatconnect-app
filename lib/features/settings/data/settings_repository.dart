import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final settingsRepositoryProvider = Provider((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

class SettingsRepository {
  final Dio _dio;

  SettingsRepository(this._dio);

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('settings');
    if (res.data is List) {
      return {};
    }
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    final res = await _dio.put('settings', data: settings);
    if (res.data is List) {
      return {};
    }
    return res.data as Map<String, dynamic>;
  }
}
