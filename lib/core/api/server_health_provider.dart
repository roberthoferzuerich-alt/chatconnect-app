import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

enum ServerStatus { checking, online, offline }

class ServerHealthNotifier extends Notifier<ServerStatus> {
  @override
  ServerStatus build() {
    checkHealth();
    return ServerStatus.checking;
  }

  Future<void> checkHealth() async {
    state = ServerStatus.checking;
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        'health',
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (response.statusCode == 200) {
        state = ServerStatus.online;
      } else {
        state = ServerStatus.offline;
      }
    } catch (_) {
      state = ServerStatus.offline;
    }
  }
}

final serverHealthProvider =
    NotifierProvider<ServerHealthNotifier, ServerStatus>(() {
  return ServerHealthNotifier();
});
