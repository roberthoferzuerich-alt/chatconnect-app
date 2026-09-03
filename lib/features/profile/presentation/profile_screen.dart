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
      } finally {
        setState(() => _isLoading = false);
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
      } finally {
        setState(() => _isLoading = false);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: CircleAvatar(
                          radius: 75,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 75,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: const Text(
                    'Name',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  subtitle: Text(
                    user.name,
                    style: const TextStyle(fontSize: 18, color: Colors.black),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.teal),
                  onTap: () => _editField(
                    'Name',
                    user.name,
                    (val) => ref
                        .read(authStateProvider.notifier)
                        .updateProfile(name: val),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.teal),
                  title: const Text(
                    'Info',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  subtitle: Text(
                    user.about ?? 'Hey there! I am using ChatConnect.',
                    style: const TextStyle(fontSize: 18, color: Colors.black),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.teal),
                  onTap: () => _editField(
                    'Info',
                    user.about ?? '',
                    (val) => ref
                        .read(authStateProvider.notifier)
                        .updateProfile(about: val),
                  ),
                ),
              ],
            ),
    );
  }
}
