import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chats_settings_provider.dart';

class ChatsSettingsScreen extends ConsumerWidget {
  const ChatsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatsSettingsProvider);
    final notifier = ref.read(chatsSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Link-Vorschauen erzeugen'),
            subtitle: const Text(
              'Für zu versendende Nachrichten Link-Vorschauen direkt von den verlinkten Webseiten abrufen.',
            ),
            value: settings.generateLinkPreviews,
            onChanged: (val) =>
                notifier.updateSetting('generateLinkPreviews', val),
          ),
          SwitchListTile(
            title: const Text('Fotos aus Adressbuch verwenden'),
            subtitle: const Text(
              'Kontaktfotos aus deinem Adressbuch anzeigen, falls verfügbar',
            ),
            value: settings.useAddressBookPhotos,
            onChanged: (val) =>
                notifier.updateSetting('useAddressBookPhotos', val),
          ),
          SwitchListTile(
            title: const Text('Stummgeschaltete Chats archiviert lassen'),
            subtitle: const Text(
              'Stummgeschaltete Chats, die archiviert sind, bleiben beim Eintreffen einer neuen Nachricht archiviert.',
            ),
            value: settings.keepMutedChatsArchived,
            onChanged: (val) =>
                notifier.updateSetting('keepMutedChatsArchived', val),
          ),
          const Divider(),
          ListTile(title: const Text('Chat-Ordner'), onTap: () {}),
          ListTile(title: const Text('Chat-Ordner hinzufügen'), onTap: () {}),
          const Divider(),
          ListTile(
            title: const Text('Chat-Verlauf exportieren'),
            subtitle: const Text(
              'Exportiere eine maschinenlesbare JSON-Kopie all deiner Chats. Verschwindende Nachrichten werden nicht exportiert.',
            ),
            onTap: () {},
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Medien & Upload',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('Maximale Bildgröße beim Upload'),
            subtitle: Text('${settings.imageUploadSize.toInt()} Pixel'),
          ),
          Slider(
            value: settings.imageUploadSize,
            min: 250,
            max: 2000,
            divisions: 7,
            label: '${settings.imageUploadSize.toInt()} px',
            onChanged: (val) =>
                notifier.updateDoubleSetting('imageUploadSize', val),
          ),
          ListTile(
            title: const Text('Thumbnail-Größe im Chat'),
            subtitle: Text('${settings.thumbnailSize.toInt()} Pixel'),
          ),
          Slider(
            value: settings.thumbnailSize,
            min: 50,
            max: 300,
            divisions: 5,
            label: '${settings.thumbnailSize.toInt()} px',
            onChanged: (val) =>
                notifier.updateDoubleSetting('thumbnailSize', val),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Tastatur',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('System-Emojis verwenden'),
            value: settings.useSystemEmojis,
            onChanged: (val) => notifier.updateSetting('useSystemEmojis', val),
          ),
          SwitchListTile(
            title: const Text('Mit Enter-Taste versenden'),
            value: settings.sendWithEnter,
            onChanged: (val) => notifier.updateSetting('sendWithEnter', val),
          ),
        ],
      ),
    );
  }
}
