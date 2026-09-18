import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/domain/user_model.dart';
import 'chat_providers.dart';
import '../data/chat_repository.dart';

class ContactSyncScreen extends ConsumerStatefulWidget {
  const ContactSyncScreen({super.key});

  @override
  ConsumerState<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends ConsumerState<ContactSyncScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Bereit zum Synchronisieren';
  List<User> _matchedUsers = [];

  @override
  void initState() {
    super.initState();
    // Automatisch beim Öffnen synchronisieren (wie bei Signal)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncContacts();
    });
  }

  Future<void> _syncContacts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Lese Kontakte...';
    });

    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );

      final phoneNumbers = <String>[];
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final cleaned = phone.number.replaceAll(RegExp(r'[^0-9+]'), '');
          if (cleaned.isNotEmpty) {
            phoneNumbers.add(cleaned);
          }
        }
      }

      try {
        final repo = ref.read(chatRepositoryProvider);
        final matched = await repo.syncContacts(phoneNumbers);

        if (mounted) {
          setState(() {
            _matchedUsers = matched;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Fehler beim Abgleich: $e';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _statusMessage = 'Zugriff auf Kontakte verweigert.';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startChatWithUser(User user) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversation = await repo.startConversation(user.id);

      ref.invalidate(conversationsProvider);

      if (mounted) {
        context.pushReplacement('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Chat-Erstellen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neuer Chat')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _matchedUsers.isEmpty
          ? Center(
              child: Text(
                _statusMessage == 'Lese Kontakte...'
                    ? 'Keine Kontakte gefunden.'
                    : _statusMessage,
              ),
            )
          : ListView.builder(
              itemCount: _matchedUsers.length,
              itemBuilder: (context, index) {
                final user = _matchedUsers[index];
                final avatarUrl = user.avatarPath != null
                    ? 'https://rhz.internet-box.ch:8443/storage/${user.avatarPath}'
                    : null;

                return ListTile(
                  onTap: () => _startChatWithUser(user),
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(user.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(user.name),
                  subtitle: const Text('Nutzt Chat Connect'),
                );
              },
            ),
    );
  }
}
