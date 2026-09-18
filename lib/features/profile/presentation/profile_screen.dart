import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/presentation/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(authStateProvider.notifier)
            .updateProfile(avatar: File(pickedFile.path));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
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

  Future<void> _editField(
    String title,
    String initialValue,
    Function(String) onSave,
  ) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title bearbeiten'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: title),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null && result.trim() != initialValue) {
      setState(() => _isLoading = true);
      try {
        await onSave(result.trim());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarUrl = user.avatarPath != null
        ? 'https://rhz.internet-box.ch:8443/storage/${user.avatarPath}'
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: InkWell(
                    onTap: _showImageSourceDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Foto bearbeiten',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name, style: const TextStyle(fontSize: 16)),
                  onTap: () => _editField(
                    'Name',
                    user.name,
                    (val) => ref
                        .read(authStateProvider.notifier)
                        .updateProfile(name: val),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(
                    user.phone != null && user.phone!.isNotEmpty
                        ? user.phone!
                        : 'Natel Nummer hinzufügen',
                    style: TextStyle(
                      fontSize: 16,
                      color: user.phone != null && user.phone!.isNotEmpty
                          ? null
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onTap: () => _editField(
                    'Natel Nummer',
                    user.phone ?? '',
                    (val) => ref
                        .read(authStateProvider.notifier)
                        .updateProfile(phone: val),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Info', style: TextStyle(fontSize: 16)),
                  subtitle: user.about != null && user.about!.isNotEmpty
                      ? Text(user.about!)
                      : null,
                  onTap: () => _editField(
                    'Info',
                    user.about ?? '',
                    (val) => ref
                        .read(authStateProvider.notifier)
                        .updateProfile(about: val),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text(
                    'Abzeichen',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {},
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Text(
                    'Dein Profil und Änderungen daran sind für Personen, an die du Nachrichten verschickst, deine Kontakte und Gruppen sichtbar.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),

                const Divider(thickness: 1, height: 1),

                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text(
                    'Nutzername',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {},
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Andere können dir jetzt über deinen optionalen Nutzernamen eine Nachricht schicken, sodass du deine Telefonnummer nicht mehr herausgeben musst.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }
}
