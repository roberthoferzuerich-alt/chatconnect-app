import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// Handler für Benachrichtigungen im Hintergrund
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  PushNotificationService(this._ref);

  Future<void> init() async {
    // Erlaubnis einholen (iOS & Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Background Handler registrieren
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Lokale Benachrichtigungen initialisieren (für Foreground Messages)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Channel für Android 8+ erstellen
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages_channel',
      'Chat Nachrichten',
      description: 'Benachrichtigungen für neue Chat-Nachrichten',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Foreground Listener einrichten
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        _showLocalNotification(message, channel);
      }
    });

    // Hole FCM Token und sende an Backend
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint("Fehler beim Abrufen des FCM Tokens: $e");
    }

    // Token Refreshes überwachen
    _fcm.onTokenRefresh.listen((token) {
      _sendTokenToBackend(token);
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint("Versuche Token an Backend zu senden: $token"); // <-- NEU
      final dio = _ref.read(apiClientProvider);
      await dio.post('fcm-token', data: {'fcm_token': token});
      debugPrint("FCM Token erfolgreich an Backend gesendet.");
    } catch (e) {
      debugPrint("FEHLER BEIM SENDEN DES TOKENS: $e"); // <-- GROSS GESCHRIEBEN
    }
  }

  void _showLocalNotification(
    RemoteMessage message,
    AndroidNotificationChannel channel,
  ) {
    _localNotifications.show(
      id: message.notification.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
