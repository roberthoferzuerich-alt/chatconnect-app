import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_provider.dart';
import 'chat_providers.dart';

class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosState = ref.watch(conversationsProvider);
    final currentUser = ref.watch(authStateProvider).value;
    final archivedIds = ref.watch(archivedChatIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archivierte Chats')),
      body: convosState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (conversations) {
          final archivedConvos = conversations
              .where((c) => archivedIds.contains(c.id))
              .toList();

          if (archivedConvos.isEmpty) {
            return const Center(child: Text('Keine archivierten Chats.'));
          }

          return ListView.builder(
            itemCount: archivedConvos.length,
            itemBuilder: (context, index) {
              final convo = archivedConvos[index];
              final otherUser = convo.users.firstWhere(
                (u) => u.id != currentUser?.id,
                orElse: () => convo.users.first,
              );

              return Dismissible(
                key: Key('archived_${convo.id}'),
                direction: DismissDirection.startToEnd,
                background: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20.0),
                  child: const Icon(
                    Icons.unarchive_outlined,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (direction) {
                  if (direction == DismissDirection.startToEnd) {
                    ref.read(archivedChatIdsProvider.notifier).update((state) {
                      final newState = Set<int>.from(state);
                      newState.remove(convo.id);
                      return newState;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat wiederhergestellt')),
                    );
                  }
                },
                child: ListTile(
                  leading: CircleAvatar(child: Text(otherUser.name[0])),
                  title: Text(
                    convo.isGroup ? convo.name ?? 'Gruppe' : otherUser.name,
                  ),
                  subtitle: Text(
                    convo.lastMessage?.content ?? 'Keine Nachrichten',
                    maxLines: 1,
                  ),
                  onTap: () => context.push('/chat/${convo.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
