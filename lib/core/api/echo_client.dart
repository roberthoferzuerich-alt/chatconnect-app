import 'dart:async';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final echoClientProvider = Provider<EchoClient?>((ref) {
  return null;
});

final echoConnectionStatusProvider = StreamProvider<String>((ref) async* {
  await EchoClient.init();
  yield* Stream.periodic(const Duration(seconds: 1), (_) {
    return EchoClient.currentState;
  });
});

class EchoClient {
  static PusherChannelsClient? _client;
  static Timer? _watchdogTimer;
  static String currentState = 'connecting';

  static Future<PusherChannelsClient> init() async {
    if (_client != null) return _client!;

    final options = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: 'rhz.internet-box.ch',
      port: 8443,
      key: 'h44wphy9thp9mkmibdqj',
    );

    _client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (error, trace, refresh) {
        print('Pusher Connection Error: $error');
        currentState = 'disconnected';
      },
    );

    // Auf echtes Connect-Event hören
    _client!.onConnectionEstablished.listen((_) {
      print('Pusher offiziell verbunden! Socket ID: ${_client!.socketId}');
      currentState = 'connected';
    });

    await _client!.connect();

    // 1-Sekunden-Watchdog: Der verlässlichste Weg
    _watchdogTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_client == null) return;

      // Keine echte Verbindung -> Reconnect
      if (currentState == 'disconnected') {
        print('Watchdog: Websocket ist tot. Versuche Reconnect...');
        currentState = 'connecting'; // Ampel auf Orange
        try {
          _client!.reconnect();
        } catch (_) {}
      }
    });

    return _client!;
  }

  static Future<PrivateChannel> subscribeToChat(int conversationId) async {
    final client = await init();
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final channel = client.privateChannel(
      'private-chat.$conversationId',
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: Uri.parse(
              'https://rhz.internet-box.ch:8443/api/broadcasting/auth',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
    );

    channel.subscribe();
    return channel;
  }

  static void disconnect() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _client?.disconnect();
    _client?.dispose();
    _client = null;
  }
}
