import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Nachrichten',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Nachrichtentöne'),
            subtitle: const Text(
              'Töne für eingehende und ausgehende Nachrichten abspielen',
            ),
            value: settings.messageTones,
            onChanged: notifier.toggleMessageTones,
            activeColor: Colors.green,
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Vibration bei eingehenden Nachrichten'),
            value: settings.vibration,
            onChanged: notifier.toggleVibration,
            activeColor: Colors.green,
          ),
          SwitchListTile(
            title: const Text('Benachrichtigungen mit hoher Priorität'),
            subtitle: const Text(
              'Vorschauen von Benachrichtigungen am oberen Bildschirmrand anzeigen',
            ),
            value: settings.highPriority,
            onChanged: notifier.toggleHighPriority,
            activeColor: Colors.green,
          ),
          SwitchListTile(
            title: const Text('Reaktionsbenachrichtigungen'),
            subtitle: const Text(
              'Benachrichtigungen für Reaktionen auf deine Nachrichten anzeigen',
            ),
            value: settings.reactionNotifications,
            onChanged: notifier.toggleReactionNotifications,
            activeColor: Colors.green,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Gruppen',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Klingelton'),
            subtitle: const Text('Standard (Stumm)'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Klingelton-Auswahl noch nicht implementiert'),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Anrufe',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Klingelton'),
            subtitle: const Text('Standard'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Klingelton-Auswahl noch nicht implementiert'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
