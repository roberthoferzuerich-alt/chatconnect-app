import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/domain/conversation_model.dart';
import '../../../chat/presentation/chat_providers.dart';

class ChatRecipientDialog extends ConsumerStatefulWidget {
  final File imageFile;
  final String? defaultCaption;

  const ChatRecipientDialog({
    super.key,
    required this.imageFile,
    this.defaultCaption,
  });

  @override
  ConsumerState<ChatRecipientDialog> createState() => _ChatRecipientDialogState();
}

class _ChatRecipientDialogState extends ConsumerState<ChatRecipientDialog> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedConversationId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultCaption != null && widget.defaultCaption!.isNotEmpty) {
      _captionController.text = widget.defaultCaption!;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convosAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(authStateProvider).value?.id;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF00A884), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Direkt in Chat senden',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111B21),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bild-Vorschau klein & Bildunterschrift
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      widget.imageFile,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        hintText: 'Nachricht hinzufügen... (optional)',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF0F2F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Suchfeld
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF00A884)),
                  hintText: 'Chat oder Kontakt suchen...',
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Liste der Chats
              Expanded(
                child: convosAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A884)),
                  ),
                  error: (err, _) => Center(
                    child: Text('Fehler beim Laden der Chats: $err'),
                  ),
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return const Center(
                        child: Text(
                          'Noch keine Chats vorhanden.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = conversations.where((convo) {
                      String chatName = '';
                      if (convo.isGroup) {
                        chatName = convo.name ?? 'Gruppe';
                      } else {
                        final other = convo.users.firstWhere(
                          (u) => u.id != currentUserId,
                          orElse: () => convo.users.first,
                        );
                        chatName = other.name;
                      }
                      return query.isEmpty || chatName.toLowerCase().contains(query);
                    }).toList();

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                      itemBuilder: (context, index) {
                        final convo = filtered[index];
                        String chatName = '';
                        String? avatarUrl;

                        if (convo.isGroup) {
                          chatName = convo.name ?? 'Gruppe';
                        } else {
                          final other = convo.users.firstWhere(
                            (u) => u.id != currentUserId,
                            orElse: () => convo.users.first,
                          );
                          chatName = other.name;
                          avatarUrl = other.fullAvatarUrl;
                        }

                        final isSelected = _selectedConversationId == convo.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF00A884).withOpacity(0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: AppAvatar(
                            avatarUrl: avatarUrl,
                            name: chatName,
                            radius: 22,
                          ),
                          title: Text(
                            chatName,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF111B21),
                            ),
                          ),
                          subtitle: convo.lastMessage?.content != null
                              ? Text(
                                  convo.lastMessage!.content!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFF00A884))
                              : Icon(Icons.circle_outlined, color: Colors.grey.shade400),
                          onTap: () {
                            setState(() {
                              _selectedConversationId = convo.id;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Button "Absenden"
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: (_selectedConversationId != null && !_isSending)
                    ? () => _sendImageToChat(_selectedConversationId!)
                    : null,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSending ? 'Wird gesendet...' : 'In Chat senden',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendImageToChat(int conversationId) async {
    setState(() => _isSending = true);
    final caption = _captionController.text.trim();

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            conversationId,
            caption.isEmpty ? null : caption,
            imagePath: widget.imageFile.path,
          );
      ref.invalidate(conversationsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00A884),
            content: const Text('✨ Bild erfolgreich in den Chat gesendet!'),
            action: SnackBarAction(
              label: 'Chat öffnen',
              textColor: Colors.white,
              onPressed: () {
                context.push('/chat/$conversationId');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Senden: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
