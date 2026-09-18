import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../story/domain/story_model.dart';
import '../../story/presentation/story_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../story/presentation/create_story_screen.dart';

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(storiesProvider);
      _checkLostData();
    });
  }

  Future<void> _checkLostData() async {
    try {
      final picker = ImagePicker();
      final response = await picker.retrieveLostData();
      if (!response.isEmpty && response.file != null) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  CreateStoryScreen(imagePath: response.file!.path),
            ),
          );
        }
      }
    } catch (e) {
      print('Lost data error: $e');
    }
  }

  Future<void> _pickAndCreateStory() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Öffne Galerie...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1080,
      );

      if (pickedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kein Bild ausgewählt oder Berechtigung fehlt.'),
            ),
          );
        }
        return;
      }

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        maxWidth: 1080,
        maxHeight: 1920,
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Story zuschneiden',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Story zuschneiden'),
        ],
      );

      if (croppedFile != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                CreateStoryScreen(imagePath: croppedFile.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schwerer Fehler beim Bild-Laden: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _playAllStories(List<UserStoryGroup>? groupedStories) {
    if (groupedStories == null || groupedStories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Keine Storys vorhanden.')));
      return;
    }

    final allStories = groupedStories.expand((group) {
      return group.stories.map(
        (s) => Story(
          id: s.id,
          userId: s.userId,
          mediaPath: s.mediaPath,
          caption: s.caption,
          expiresAt: s.expiresAt,
          createdAt: s.createdAt,
          user: s.user ?? group.user,
        ),
      );
    }).toList();

    context.push('/view_story', extra: allStories);
  }

  @override
  Widget build(BuildContext context) {
    final storiesState = ref.watch(storiesProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storys',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.slideshow),
            onPressed: () => _playAllStories(storiesState.value),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(storiesProvider),
        child: ListView(
          children: [
            storiesState.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) => Center(child: Text('Fehler: $e')),
              data: (groupedStories) {
                // Eigene Story herausfiltern
                final myStoryGroup = groupedStories
                    .where((g) => g.user.id == currentUser?.id)
                    .firstOrNull;
                final friendsStories = groupedStories
                    .where((g) => g.user.id != currentUser?.id)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- MEINE STORY BEREICH ---
                    ListTile(
                      leading: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (myStoryGroup != null) {
                                final storiesWithUser = myStoryGroup.stories
                                    .map(
                                      (s) => Story(
                                        id: s.id,
                                        userId: s.userId,
                                        mediaPath: s.mediaPath,
                                        caption: s.caption,
                                        expiresAt: s.expiresAt,
                                        createdAt: s.createdAt,
                                        user: s.user ?? myStoryGroup.user,
                                      ),
                                    )
                                    .toList();
                                context.push(
                                  '/view_story',
                                  extra: storiesWithUser,
                                );
                              } else {
                                _pickAndCreateStory();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: myStoryGroup != null
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: currentUser?.avatarPath != null
                                    ? CachedNetworkImageProvider(
                                        'https://rhz.internet-box.ch:8443/storage/${currentUser!.avatarPath}',
                                      )
                                    : null,
                                child: currentUser?.avatarPath == null
                                    ? (myStoryGroup != null
                                          ? Text(
                                              currentUser?.name[0]
                                                      .toUpperCase() ??
                                                  'I',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 24,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 30,
                                            ))
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndCreateStory,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: const Text(
                        'Meine Story',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        myStoryGroup != null
                            ? 'Tippen zum Ansehen'
                            : 'Tippen, um Status-Update hinzuzufÃƒÂ¼gen',
                      ),
                      onTap: () {
                        if (myStoryGroup != null) {
                          // Eigene Story-Detailansicht ansehen
                          context.push('/my_stories', extra: myStoryGroup);
                        } else {
                          // Neue erstellen
                          _pickAndCreateStory();
                        }
                      },
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Aktuelle Updates',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // --- FREUNDE STORYS ---
                    if (friendsStories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'Keine neuen Storys von deinen Kontakten.',
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friendsStories.length,
                        itemBuilder: (context, index) {
                          final group = friendsStories[index];
                          final latestStory = group.stories.last;
                          final timeStr = DateFormat(
                            'HH:mm',
                          ).format(latestStory.createdAt);

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.blue.shade900,
                                backgroundImage: group.user.avatarPath != null
                                    ? CachedNetworkImageProvider(
                                        'https://rhz.internet-box.ch:8443/storage/${group.user.avatarPath}',
                                      )
                                    : null,
                                child: group.user.avatarPath == null
                                    ? Text(group.user.name[0].toUpperCase())
                                    : null,
                              ),
                            ),
                            title: Text(
                              group.user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Heute, $timeStr Uhr'),
                            onTap: () {
                              final storiesWithUser = group.stories
                                  .map(
                                    (s) => Story(
                                      id: s.id,
                                      userId: s.userId,
                                      mediaPath: s.mediaPath,
                                      caption: s.caption,
                                      expiresAt: s.expiresAt,
                                      createdAt: s.createdAt,
                                      user: s.user ?? group.user,
                                    ),
                                  )
                                  .toList();
                              context.push(
                                '/view_story',
                                extra: storiesWithUser,
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
