import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:story_view/story_view.dart';
import '../domain/story_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/story_repository.dart';
import '../../auth/presentation/auth_provider.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<Story> stories;

  const StoryViewerScreen({super.key, required this.stories});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  final StoryController controller = StoryController();
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<StoryItem> storyItems;
  int currentIndex = 0;
  final Set<int> _viewedStories = {};

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        controller.pause();
      } else {
        controller.play();
      }
    });

    String getFullUrl(String path) {
      if (path.startsWith('http')) return path;
      if (path.startsWith('/storage')) {
        return 'https://rhz.internet-box.ch:8443$path';
      }
      if (path.startsWith('storage')) {
        return 'https://rhz.internet-box.ch:8443/$path';
      }
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      return 'https://rhz.internet-box.ch:8443/storage/$path';
    }

    storyItems = widget.stories.map((s) {
      return StoryItem.pageImage(
        url: getFullUrl(s.mediaPath),
        controller: controller,
        caption: s.caption != null
            ? Text(
                s.caption!,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            : null,
      );
    }).toList();
  }

  @override
  void dispose() {
    controller.dispose();
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendReaction(Story story, {String? reaction, String? message}) async {
    try {
      await ref
          .read(storyRepositoryProvider)
          .viewStory(story.id, reaction: reaction, message: message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gesendet!'),
            duration: Duration(seconds: 1),
          ),
        );
        _msgController.clear();
        _focusNode.unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Senden: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final currentStory = widget.stories[currentIndex];
    final currentUser = currentStory.user;
    final myUser = ref.watch(authStateProvider).value;
    final isOwner = myUser != null && currentStory.userId == myUser.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StoryView(
            storyItems: storyItems,
            controller: controller,
            onComplete: () => context.pop(),
            onStoryShow: (s, index) {
              if (index != currentIndex && mounted) {
                setState(() {
                  currentIndex = index;
                });
              }

              if (mounted) {
                final story = widget.stories[index];
                if (!_viewedStories.contains(story.id)) {
                  _viewedStories.add(story.id);
                  ref
                      .read(storyRepositoryProvider)
                      .viewStory(story.id)
                      .catchError((_) {});
                }
              }
            },
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) {
                context.pop();
              }
            },
          ),
          if (currentUser != null)
            Positioned(
              top: 60,
              left: 10,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: currentUser.avatarPath != null
                        ? CachedNetworkImageProvider(
                            'https://rhz.internet-box.ch:8443/storage/${currentUser.avatarPath}',
                          )
                        : null,
                    child: currentUser.avatarPath == null
                        ? Text(
                            currentUser.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (!isOwner)
            Positioned(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Antworten...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black54,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () {
                            if (_msgController.text.trim().isNotEmpty) {
                              _sendReaction(
                                currentStory,
                                message: _msgController.text.trim(),
                              );
                            }
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _sendReaction(currentStory, message: val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendReaction(currentStory, reaction: 'heart'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
