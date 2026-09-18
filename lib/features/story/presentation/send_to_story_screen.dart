import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/story_repository.dart';
import 'story_providers.dart';

class SendToStoryScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String? caption;

  const SendToStoryScreen({super.key, required this.imagePath, this.caption});

  @override
  ConsumerState<SendToStoryScreen> createState() => _SendToStoryScreenState();
}

class _SendToStoryScreenState extends ConsumerState<SendToStoryScreen> {
  bool _isUploading = false;
  bool _isSelected = true;

  Future<void> _send() async {
    if (!_isSelected) return;
    setState(() => _isUploading = true);
    try {
      await ref
          .read(storyRepositoryProvider)
          .uploadStory(widget.imagePath, caption: widget.caption);
      ref.invalidate(storiesProvider);
      if (mounted) {
        context.go('/chats');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Senden: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111B21),
        foregroundColor: Colors.white,
        title: const Text('Senden an', style: TextStyle(fontSize: 20)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Card
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image,
                                  size: 80,
                                  color: Colors.white54,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Meine Storys Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Meine Storys',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white70,
                            size: 18,
                          ),
                          label: const Text(
                            'Neu',
                            style: TextStyle(color: Colors.white70),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Meine Story List Item
                    InkWell(
                      onTap: () {
                        setState(() => _isSelected = !_isSelected);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blueGrey,
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Meine Story',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Alle Kontakte · Sichtbar für 24 Stunden',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: _isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.white38,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: _isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : const SizedBox(width: 18, height: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFF1F2C34),
              child: Row(
                children: [
                  const Text(
                    'Meine Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  FloatingActionButton(
                    heroTag: 'send_story_btn',
                    onPressed: _isUploading ? null : _send,
                    backgroundColor: const Color(0xFF2563EB),
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
