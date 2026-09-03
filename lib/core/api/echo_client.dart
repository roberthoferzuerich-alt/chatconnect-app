import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

final echoClientProvider = Provider<EchoClient?>((ref) {
  return null;
});

class EchoClient {
  static PusherChannelsClient? _client;

  static Future<PusherChannelsClient> init() async {
    if (_client != null) return _client!;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

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
        refresh();
      },
    );

    await _client!.connect();
    return _client!;
  }

  static Future<PrivateChannel> subscribeToChat(int conversationId) async {
    final client = await init();
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final channel = client.privateChannel(
      'private-chat.$conversationId', // In Laravel Echo it's 'private-chat', the prefix is added automatically by Echo, but here we must add it manually or check Laravel's implementation. Actually Laravel channels are prefixed with 'private-' for Private channels.
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
    _client?.disconnect();
    _client?.dispose();
    _client = null;
  }
}
