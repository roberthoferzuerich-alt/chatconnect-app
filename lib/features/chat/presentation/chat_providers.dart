import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/call_record.dart';
import '../../../core/api/echo_client.dart';
import '../../auth/presentation/auth_provider.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
      () => ConversationsNotifier(),
    );

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final repo = ref.read(chatRepositoryProvider);
    return repo.getConversations();
  }

  Future<void> deleteConversation(int id) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.deleteConversation(id);
      if (state.hasValue) {
        state = AsyncValue.data(state.value!.where((c) => c.id != id).toList());
      }
    } catch (e) {}
  }
}

class ArchivedChatIdsNotifier extends StateNotifier<Set<int>> {
  static const _prefsKey = 'cc_archived_chat_ids_v1';

  ArchivedChatIdsNotifier() : super(<int>{}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const [];
      state = list.map((s) => int.tryParse(s)).whereType<int>().toSet();
    } catch (_) {}
  }

  Future<void> _save(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        ids.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }

  Set<int> update(Set<int> Function(Set<int> state) cb) {
    final next = cb(state);
    state = next;
    _save(next);
    return next;
  }
}

final archivedChatIdsProvider =
    StateNotifierProvider<ArchivedChatIdsNotifier, Set<int>>(
      (ref) => ArchivedChatIdsNotifier(),
    );

class StarredMessageIdsNotifier extends StateNotifier<Set<int>> {
  static const _prefsKey = 'cc_starred_msg_ids_v1';

  StarredMessageIdsNotifier() : super(<int>{}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const [];
      state = list.map((s) => int.tryParse(s)).whereType<int>().toSet();
    } catch (_) {}
  }

  Future<void> toggle(int messageId) async {
    final next = Set<int>.from(state);
    if (next.contains(messageId)) {
      next.remove(messageId);
    } else {
      next.add(messageId);
    }
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        next.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }
}

final starredMessageIdsProvider =
    StateNotifierProvider<StarredMessageIdsNotifier, Set<int>>(
      (ref) => StarredMessageIdsNotifier(),
    );

final callsProvider = FutureProvider<List<CallRecord>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getCalls();
});

final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesNotifier, AsyncValue<List<Message>>, int>((
      ref,
      conversationId,
    ) {
      final currentUserId = ref.watch(authStateProvider).value?.id;
      return MessagesNotifier(
        ref.watch(chatRepositoryProvider),
        conversationId,
        currentUserId,
      );
    });

class MessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final ChatRepository _repo;
  final int _conversationId;
  final int? _currentUserId;
  PrivateChannel? _channel;
  Timer? _pollingTimer;

  MessagesNotifier(this._repo, this._conversationId, this._currentUserId)
    : super(const AsyncValue.loading()) {
    loadMessages();
    _initEcho();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollNewMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  String _messagesSignature(List<Message> list) {
    final sb = StringBuffer();
    for (final m in list) {
      sb.write('${m.id}:${m.readAt != null ? 1 : 0}:');
      for (final r in m.reactions) {
        if (r is Map) {
          sb.write('${r['user_id']}_${r['reaction']},');
        }
      }
      sb.write(';');
    }
    return sb.toString();
  }

  Future<void> _pollNewMessages() async {
    if (!mounted) return;
    try {
      final msgs = await _repo.getMessages(_conversationId);
      if (!mounted) return;
      if (state.hasValue) {
        final currentMsgs = state.value!;
        if (_messagesSignature(msgs) != _messagesSignature(currentMsgs)) {
          state = AsyncValue.data(msgs);
          final hasUnreadFromOther = msgs.any(
            (m) => m.senderId != _currentUserId && m.readAt == null,
          );
          if (hasUnreadFromOther) {
            _repo.markAsRead(_conversationId).catchError((_) {});
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _initEcho() async {
    try {
      _channel = await EchoClient.subscribeToChat(_conversationId);

      _channel!.bind('App\\Events\\MessageSent').listen((event) {
        if (!mounted) return;
        try {
          dynamic data = event.data;
          if (data is String) data = jsonDecode(data);
          if (data != null && data['message'] != null) {
            final newMsg = Message.fromJson(data['message']);
            if (newMsg.senderId == _currentUserId) return;
            if (state.hasValue) {
              final currentList = state.value!;
              if (!currentList.any((m) => m.id == newMsg.id)) {
                state = AsyncValue.data([...currentList, newMsg]);
              }
            }
            _repo.markAsRead(_conversationId);
          }
        } catch (e) {
          print('Error parsing WebSocket message: \$e');
        }
      });
      _channel!.bind('App\\Events\\MessagesRead').listen((event) {
        if (state.hasValue) {
          final currentList = state.value!;
          final now = DateTime.now();
          state = AsyncValue.data(
            currentList.map((m) {
              if (m.senderId == _currentUserId && m.readAt == null) {
                return m.copyWith(readAt: now);
              }
              return m;
            }).toList(),
          );
        }
      });
      _channel!.bind('App\\Events\\MessageDeleted').listen((event) {
        if (!mounted) return;
        try {
          dynamic data = event.data;
          if (data is String) data = jsonDecode(data);
          final deletedId = data['messageId'] ?? data['message_id'];
          if (deletedId != null && state.hasValue) {
            state = AsyncValue.data(
              state.value!.where((m) => m.id != deletedId).toList(),
            );
          }
        } catch (_) {}
      });
    } catch (e) {
      print('WebSocket Error: \$e');
    }
  }

  Future<void> loadMessages() async {
    try {
      final msgs = await _repo.getMessages(_conversationId);
      state = AsyncValue.data(msgs);
      _repo.markAsRead(_conversationId).catchError((_) {});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendMessage(
    String? content, {
    String? imagePath,
    String? audioPath,
    String? documentPath,
    String? documentName,
  }) async {
    try {
      final newMsg = await _repo.sendMessage(
        _conversationId,
        content,
        imagePath: imagePath,
        audioPath: audioPath,
        documentPath: documentPath,
        documentName: documentName,
      );
      if (state.hasValue) {
        state = AsyncValue.data([...state.value!, newMsg]);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _repo.deleteMessage(messageId);
      if (state.hasValue) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.where((m) => m.id != messageId).toList(),
        );
      }
    } catch (e) {}
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    try {
      final updatedMsg = await _repo.reactToMessage(messageId, emoji);
      if (state.hasValue) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.map((m) => m.id == messageId ? updatedMsg : m).toList(),
        );
      }
    } catch (e) {}
  }
}
