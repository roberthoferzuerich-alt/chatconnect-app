import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../../auth/domain/user_model.dart';
import 'chat_providers.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final users = await ref.read(chatRepositoryProvider).searchUsers(query);
      setState(() => _users = users);
    } catch (e) {
      // Ignorieren für einfaches MVP
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(int userId) async {
    try {
      final convo = await ref
          .read(chatRepositoryProvider)
          .startConversation(userId);
      ref.invalidate(conversationsProvider);
      if (mounted) {
        context.pushReplacement('/chat/${convo.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Benutzer suchen...',
            border: InputBorder.none,
          ),
          onChanged: _search,
          autofocus: true,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final avatarUrl = user.avatarPath != null && user.avatarPath!.isNotEmpty
                    ? 'https://rhz.internet-box.ch:8443/storage/${user.avatarPath}'
                    : null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(user.about != null && user.about!.isNotEmpty ? user.about! : user.email),
                  onTap: () => _startChat(user.id),
                );
              },
            ),
    );
  }
}
