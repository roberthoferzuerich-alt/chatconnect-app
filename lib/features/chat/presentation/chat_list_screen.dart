import 'package:app/app/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/chat_repository.dart';
import 'chat_providers.dart';
import '../../story/presentation/story_providers.dart';
import '../../story/domain/story_model.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/connection_indicator.dart';
import '../../settings/presentation/widgets/chat_font_size_dialog.dart';

class UnreadFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final unreadFilterProvider = NotifierProvider<UnreadFilterNotifier, bool>(() {
  return UnreadFilterNotifier();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosState = ref.watch(conversationsProvider);
    final currentUser = ref.watch(authStateProvider).value;
    final archivedIds = ref.watch(archivedChatIdsProvider);
    final showUnreadOnly = ref.watch(unreadFilterProvider);

    final avatarUrl = currentUser?.fullAvatarUrl;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: AppAvatar(
            avatarUrl: avatarUrl,
            name: currentUser?.name ?? '',
            radius: 20,
            onTap: () => context.push('/settings'),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ChatConnect',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (currentUser != null && currentUser.name.isNotEmpty)
              Text(
                currentUser.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          const Center(child: ConnectionIndicator()),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authStateProvider.notifier).logout();
              } else if (value == 'new_group') {
                context.push('/create_group');
              } else if (value == 'read_all') {
                ref.read(chatRepositoryProvider).markAllAsRead().then((_) {
                  ref.refresh(conversationsProvider.future);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alle Chats als gelesen markiert'),
                      ),
                    );
                  }
                });
              } else if (value == 'filter_unread') {
                ref.read(unreadFilterProvider.notifier).toggle();
              } else if (value == 'notification_profile') {
                context.push('/settings_notifications');
              } else if (value == 'archived') {
                context.push('/archived_chats');
              } else if (value == 'font_size') {
                showChatFontSizeDialog(context);
              } else if (value == 'user_guide') {
                context.push('/user_guide');
              } else if (value == 'settings') {
                context.push('/settings');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_group',
                child: Text('Neue Gruppe'),
              ),
              const PopupMenuItem(
                value: 'read_all',
                child: Text('Alle als gelesen markieren'),
              ),
              PopupMenuItem(
                value: 'filter_unread',
                child: Text(
                  showUnreadOnly
                      ? 'Alle Chats anzeigen'
                      : 'Ungelesene Chats filtern',
                ),
              ),
              const PopupMenuItem(
                value: 'notification_profile',
                child: Text('Benachrichtigungsprofil'),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: Text('Archivierte Chats'),
              ),
              const PopupMenuItem(
                value: 'font_size',
                child: Text('Chat-Schriftgröße'),
              ),
              const PopupMenuItem(
                value: 'user_guide',
                child: Text('Benutzeranleitung'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Einstellungen'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Abmelden')),
            ],
          ),
        ],
      ),
      body: convosState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (conversations) {
          final baseConvos = conversations.where(
            (c) => !archivedIds.contains(c.id),
          );

          final activeConvos =
              (showUnreadOnly
                      ? baseConvos.where(
                          (c) =>
                              c.lastMessage != null &&
                              c.lastMessage!.readAt == null &&
                              c.lastMessage!.senderId != currentUser?.id,
                        )
                      : baseConvos)
                  .toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const _StoryBar(),
                if (activeConvos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text('Noch keine Chats. Starte einen neuen!'),
                    ),
                  )
                else
                  ...activeConvos.map((convo) {
                    final otherUser = convo.users.firstWhere(
                      (u) => u.id != currentUser?.id,
                      orElse: () => convo.users.first,
                    );
                    final avatarUrl = !convo.isGroup ? otherUser.fullAvatarUrl : null;

                    return Dismissible(
                      key: Key('convo_${convo.id}'),
                      background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20.0),
                        child: const Icon(
                          Icons.archive_outlined,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (direction) {
                        if (direction == DismissDirection.startToEnd) {
                          ref.read(archivedChatIdsProvider.notifier).update((
                            state,
                          ) {
                            final newState = Set<int>.from(state);
                            newState.add(convo.id);
                            return newState;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat archiviert')),
                          );
                        } else if (direction == DismissDirection.endToStart) {
                          ref
                              .read(conversationsProvider.notifier)
                              .deleteConversation(convo.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat gelöscht')),
                          );
                        }
                      },
                      child: ListTile(
                        leading: AppAvatar(
                          avatarUrl: avatarUrl,
                          name: convo.isGroup
                              ? (convo.name ?? 'Gruppe')
                              : otherUser.name,
                          isGroup: convo.isGroup,
                          radius: 24,
                        ),
                        title: Text(
                          convo.isGroup
                              ? convo.name ?? 'Gruppe'
                              : otherUser.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          convo.lastMessage == null
                              ? 'Keine Nachrichten'
                              : (convo.lastMessage!.content.isNotEmpty
                                    ? convo.lastMessage!.content
                                    : (convo.lastMessage!.fileUrl != null
                                          ? '📄 ${convo.lastMessage!.fileName ?? "Dokument"}'
                                          : (convo.lastMessage!.audioUrl != null
                                                ? '🎤 Sprachnachricht'
                                                : (convo.lastMessage!.imageUrl !=
                                                          null
                                                      ? '📷 Foto'
                                                      : 'Keine Nachrichten')))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => context.push('/chat/${convo.id}'),
                      ),
                    );
                  }),
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Leg los',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    children: [
                      _buildActionCard(
                        'Neue Gruppe',
                        Icons.group_outlined,
                        Colors.orange.shade100.withOpacity(0.5),
                        onTap: () => context.push('/create_group'),
                      ),
                      _buildActionCard(
                        'Kontakte einladen',
                        Icons.mail_outline,
                        Colors.green.shade100.withOpacity(0.5),
                        onTap: () {
                          Share.share(
                            'Hey! Lade dir ChatConnect herunter, damit wir chatten und telefonieren können: https://chatconnect.app',
                          );
                        },
                      ),
                      _buildActionCard(
                        'Farbe einstellen',
                        Icons.palette_outlined,
                        Colors.blue.shade100.withOpacity(0.5),
                        onTap: () => _showColorPicker(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Space for FABs
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'camera_fab',
            backgroundColor: Theme.of(context).cardColor,
            elevation: 2,
            onPressed: () async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
              );
              if (picked != null && context.mounted) {
                context.push('/create_story', extra: picked.path);
              }
            },
            child: const Icon(Icons.camera_alt_outlined),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'edit_fab',
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            elevation: 2,
            onPressed: () => context.push('/sync_contacts'),
            child: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.green,
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App-Farbe wählen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: colors.map((color) {
                    final isSelected = ref.watch(themeColorProvider) == color;
                    return GestureDetector(
                      onTap: () {
                        ref.read(themeColorProvider.notifier).setColor(color);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color bgColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.black54,
                  ),
                  onPressed: () {},
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.black87),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryBar extends ConsumerWidget {
  const _StoryBar();

  Future<void> _pickStoryImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null && context.mounted) {
      context.push('/create_story', extra: picked.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesState = ref.watch(storiesProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: storiesState.when(
        data: (storyGroups) {
          // Find my own story group if it exists
          final myGroupIndex = storyGroups.indexWhere(
            (g) => g.user.id == currentUser?.id,
          );
          UserStoryGroup? myGroup;
          if (myGroupIndex >= 0) {
            myGroup = storyGroups.removeAt(myGroupIndex);
          }

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              // My Story item
              GestureDetector(
                onTap: () {
                  if (myGroup != null && myGroup.stories.isNotEmpty) {
                    // View my stories
                    context.push('/view_story', extra: myGroup.stories);
                  } else {
                    // Create new story
                    _pickStoryImage(context);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    (myGroup != null &&
                                        myGroup.stories.isNotEmpty)
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: AppAvatar(
                              avatarUrl: currentUser?.fullAvatarUrl,
                              name: currentUser?.name ?? '',
                              radius: 28,
                            ),
                          ),
                          if (myGroup == null || myGroup.stories.isEmpty)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Meine Story', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),

              // Friends stories
              ...storyGroups.map((group) {
                return GestureDetector(
                  onTap: () {
                    context.push('/view_story', extra: group.stories);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          child: AppAvatar(
                            avatarUrl: group.user.fullAvatarUrl,
                            name: group.user.name,
                            radius: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.user.name.split(' ')[0],
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Icon(Icons.error_outline)),
      ),
    );
  }
}
