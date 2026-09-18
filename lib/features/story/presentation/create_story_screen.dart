import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/story_repository.dart';
import 'story_providers.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const CreateStoryScreen({super.key, required this.imagePath});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _captionCtrl = TextEditingController();
  bool _isUploading = false;

  Future<void> _upload() async {
    setState(() => _isUploading = true);
    try {
      await ref
          .read(storyRepositoryProvider)
          .uploadStory(widget.imagePath, caption: _captionCtrl.text.trim());
      ref.invalidate(storiesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Text(
                    'Bild konnte nicht geladen werden',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Bildunterschrift hinzufügen...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: _isUploading ? null : _upload,
                    backgroundColor: Colors.blue,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

