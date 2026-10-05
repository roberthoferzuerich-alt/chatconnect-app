import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chats_settings_provider.dart';
import '../../auth/presentation/auth_provider.dart';

class ChatsSettingsScreen extends ConsumerWidget {
  const ChatsSettingsScreen({super.key});

  Future<void> _pickAndCropWallpaper(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedFile == null) return;

    final cropper = ImageCropper();
    final croppedFile = await cropper.cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Hintergrund zuschneiden',
          toolbarColor: theme.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.square,
          ],
        ),
        IOSUiSettings(
          title: 'Hintergrund zuschneiden',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );

    if (croppedFile != null && context.mounted) {
      await ref.read(chatsSettingsProvider.notifier).setWallpaper(croppedFile.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat-Hintergrundbild erfolgreich aktualisiert!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatsSettingsProvider);
    final notifier = ref.read(chatsSettingsProvider.notifier);
    final currentUser = ref.watch(authStateProvider).value;

    final hasCustomWallpaper = (settings.wallpaperPath != null &&
            File(settings.wallpaperPath!).existsSync()) ||
        (currentUser?.fullWallpaperUrl != null);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView(
        children: [
          // Chat Wallpaper Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: (settings.wallpaperPath != null &&
                            File(settings.wallpaperPath!).existsSync())
                        ? Image.file(
                            File(settings.wallpaperPath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : (currentUser?.fullWallpaperUrl != null)
                            ? CachedNetworkImage(
                                imageUrl: currentUser!.fullWallpaperUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                  child: Icon(Icons.broken_image, size: 40),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wallpaper_outlined,
                                      size: 40,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Standard Chat-Hintergrund',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chat-Hintergrundbild',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Wähle ein eigenes Foto und schneide den perfekten Ausschnitt für deine Chats zurecht.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _pickAndCropWallpaper(context, ref),
                                icon: const Icon(Icons.crop_outlined, size: 18),
                                label: const Text('Bild wählen & zuschneiden'),
                              ),
                            ),
                            if (hasCustomWallpaper) ...[
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Standard wiederherstellen',
                                onPressed: () async {
                                  await notifier.resetWallpaper();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Hintergrundbild auf Standard zurückgesetzt',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

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
