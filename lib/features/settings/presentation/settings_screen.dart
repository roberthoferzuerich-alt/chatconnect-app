import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../app/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        maxWidth: 512,
        maxHeight: 512,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Profilbild zuschneiden',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Profilbild zuschneiden',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isLoading = true);
        try {
          await ref
              .read(authStateProvider.notifier)
              .updateProfile(avatar: File(croppedFile.path));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fehler beim Speichern: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    final currentTheme = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Darstellung wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System-Standard'),
              value: ThemeMode.system,
              groupValue: currentTheme,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).setTheme(val!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Hell'),
              value: ThemeMode.light,
              groupValue: currentTheme,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).setTheme(val!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dunkel'),
              value: ThemeMode.dark,
              groupValue: currentTheme,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).setTheme(val!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final avatarUrl = currentUser?.avatarPath != null
        ? 'https://rhz.internet-box.ch:8443/storage/${currentUser!.avatarPath}'
        : null;

    // Wir lassen den Hintergrund dynamisch durch das Theme bestimmen, anstatt hardcoded Colors.white
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Einstellungen')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Profil-Kopfzeile
                InkWell(
                  onTap: () => context.push('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? (currentUser?.name != null
                                      ? Text(
                                          currentUser!.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 28,
                                            color: Colors.black54,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        ))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?.name ?? 'Nutzer',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _buildSettingsItem(Icons.devices, 'Gekoppelte Geräte'),

                const Divider(thickness: 1, height: 24),

                _buildSettingsItem(
                  Icons.brightness_medium_outlined,
                  'Darstellung',
                  onTap: _showThemeDialog,
                ),
                _buildSettingsItem(
                  Icons.chat_bubble_outline,
                  'Chats',
                  onTap: () => context.push('/settings_chats'),
                ),
                _buildSettingsItem(
                  Icons.amp_stories_outlined,
                  'Storys',
                  onTap: () => context.push('/settings_stories'),
                ),
                _buildSettingsItem(
                  Icons.notifications_none,
                  'Benachrichtigungen',
                  onTap: () => context.push('/settings_notifications'),
                ),
                _buildSettingsItem(
                  Icons.lock_outline,
                  'Datenschutz',
                  onTap: () => context.push('/settings_privacy'),
                ),
                _buildSettingsItem(
                  Icons.restore,
                  'Backups',
                  onTap: () => context.push('/settings_backups'),
                ),
                _buildSettingsItem(
                  Icons.data_usage,
                  'Daten und Speicher',
                  onTap: () => context.push('/settings_storage'),
                ),

                const Divider(thickness: 1, height: 24),
                _buildSettingsItem(
                  Icons.help_outline,
                  'Benutzerhandbuch',
                  onTap: () => context.push('/user_guide'),
                ),

                _buildSettingsItem(
                  Icons.info_outline,
                  'Über mich',
                  onTap: () {
                    context.push('/about_me');
                  },
                ),
                // Abmelden Button
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Abmelden',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    ref.read(authStateProvider.notifier).logout();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap ?? () {},
    );
  }
}
