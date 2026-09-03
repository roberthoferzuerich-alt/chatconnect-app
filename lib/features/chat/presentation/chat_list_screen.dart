import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_provider.dart';
import 'chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosState = ref.watch(conversationsProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: convosState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Text('Noch keine Chats. Starte einen neuen!'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final convo = conversations[index];
                final otherUser = convo.users.firstWhere(
                  (u) => u.id != currentUser?.id,
                  orElse: () => convo.users.first,
                );

                return ListTile(
                  leading: CircleAvatar(child: Text(otherUser.name[0])),
                  title: Text(
                    convo.isGroup ? convo.name ?? 'Gruppe' : otherUser.name,
                  ),
                  subtitle: Text(
                    convo.lastMessage?.content ?? 'Keine Nachrichten',
                    maxLines: 1,
                  ),
                  onTap: () => context.push('/chat/${convo.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/search'),
        child: const Icon(Icons.message),
      ),
    );
  }
}
