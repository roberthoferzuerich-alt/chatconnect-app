import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../domain/story_model.dart';
import '../data/story_repository.dart';
import 'story_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/data/chat_repository.dart';

import '../../auth/presentation/auth_provider.dart';

class MyStoriesScreen extends ConsumerWidget {
  final UserStoryGroup storyGroup;

  const MyStoriesScreen({super.key, required this.storyGroup});

  void _showInfoDialog(BuildContext context, Story story) {
    final createdStr = DateFormat('dd.MM.yyyy HH:mm').format(story.createdAt);
    final expiresStr = DateFormat('dd.MM.yyyy HH:mm').format(story.expiresAt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Story Info'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Erstellt am: $createdStr'),
              Text('Läuft ab am: $expiresStr'),
              const SizedBox(height: 16),
              Text(
                '${story.viewsCount} Aufrufe',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (story.viewers.isNotEmpty) ...[
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: story.viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = story.viewers[index];
                      final timeStr = DateFormat(
                        'HH:mm',
                      ).format(viewer.createdAt);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: viewer.user.avatarPath != null
                              ? NetworkImage(
                                  'https://rhz.internet-box.ch:8443/storage/${viewer.user.avatarPath}',
                                )
                              : null,
                          child: viewer.user.avatarPath == null
                              ? Text(viewer.user.name[0])
                              : null,
                        ),
                        title: Text(viewer.user.name),
                        subtitle: viewer.message != null
                            ? Text(viewer.message!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (viewer.reaction == 'heart')
                              const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 20,
                              ),
                            const SizedBox(width: 4),
                            Text(timeStr, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<String?> _downloadImageToTemp(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/story_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(url, tempPath);
      return tempPath;
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleDownload(BuildContext context, Story story) async {
    final url = 'https://rhz.internet-box.ch:8443/storage/${story.mediaPath}';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bild wird heruntergeladen...')),
    );
    try {
      final tempPath = await _downloadImageToTemp(url);
      if (tempPath != null) {
        await Gal.putImage(tempPath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bild erfolgreich in der Galerie gespeichert!'),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehler beim Herunterladen.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Speichern in der Galerie.'),
          ),
        );
      }
    }
  }

  Future<void> _handleShare(BuildContext context, Story story) async {
    final url = 'https://rhz.internet-box.ch:8443/storage/${story.mediaPath}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bild wird vorbereitet...')));
    final path = await _downloadImageToTemp(url);
    if (path != null && context.mounted) {
      await Share.shareXFiles([XFile(path)], text: 'Schau dir diese Story an!');
    }
  }

  void _showForwardDialog(BuildContext context, WidgetRef ref, Story story) {
    final currentUser = ref.read(authStateProvider).value;

    showDialog(
      context: context,
      builder: (ctx) {
        final conversationsAsync = ref.watch(conversationsProvider);

        return AlertDialog(
          title: const Text('Weiterleiten an...'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: conversationsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const Center(child: Text('Keine Chats gefunden.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  itemBuilder: (ctx, index) {
                    final conv = conversations[index];
                    final otherUser = conv.users.firstWhere(
                      (u) => u.id != currentUser?.id,
                      orElse: () => conv.users.first,
                    );

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: otherUser.avatarPath != null
                            ? NetworkImage(
                                'https://rhz.internet-box.ch:8443/storage/${otherUser.avatarPath}',
                              )
                            : null,
                        child: otherUser.avatarPath == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(otherUser.name),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final url =
                            'https://rhz.internet-box.ch:8443/storage/${story.mediaPath}';
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sende...')),
                        );
                        final path = await _downloadImageToTemp(url);
                        if (path != null && context.mounted) {
                          try {
                            await ref
                                .read(chatRepositoryProvider)
                                .sendMessage(
                                  conv.id,
                                  'Schau dir diese Story an!',
                                  imagePath: path,
                                );
                            ref.invalidate(conversationsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Erfolgreich weitergeleitet!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fehler beim Weiterleiten.'),
                                ),
                              );
                            }
                          }
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Fehler beim Laden.')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Storys'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Meine Story',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: storyGroup.stories.length,
              itemBuilder: (context, index) {
                final story = storyGroup.stories[index];

                final difference = DateTime.now().difference(story.createdAt);
                String timeString = '';
                if (difference.inMinutes < 60) {
                  timeString = '${difference.inMinutes} Min.';
                } else {
                  timeString = '${difference.inHours} Std.';
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://rhz.internet-box.ch:8443/storage/${story.mediaPath}',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    '${story.viewsCount} Aufrufe',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(timeString),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.download_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: () => _handleDownload(context, story),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await ref
                                .read(storyRepositoryProvider)
                                .deleteStory(story.id);
                            ref.invalidate(storiesProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Story gelöscht')),
                              );
                              if (storyGroup.stories.length <= 1) {
                                context.pop();
                              }
                            }
                          } else if (value == 'info') {
                            _showInfoDialog(context, story);
                          } else if (value == 'share') {
                            _handleShare(context, story);
                          } else if (value == 'forward') {
                            _showForwardDialog(context, ref, story);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'forward',
                            child: Row(
                              children: const [
                                Icon(Icons.forward_to_inbox, size: 20),
                                SizedBox(width: 12),
                                Text('Weiterleiten'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: const [
                                Icon(Icons.share, size: 20),
                                SizedBox(width: 12),
                                Text('Teilen'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'info',
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 12),
                                Text('Info'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Löschen',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    final singleStoryWithUser = Story(
                      id: story.id,
                      userId: story.userId,
                      mediaPath: story.mediaPath,
                      caption: story.caption,
                      expiresAt: story.expiresAt,
                      createdAt: story.createdAt,
                      user: story.user ?? storyGroup.user,
                      viewsCount: story.viewsCount,
                    );
                    context.push('/view_story', extra: [singleStoryWithUser]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
