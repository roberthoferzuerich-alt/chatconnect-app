import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../../../core/api/echo_client.dart';
import '../../auth/presentation/auth_provider.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  return ref.watch(chatRepositoryProvider).getConversations();
});

final messagesProvider =
    StateNotifierProvider.family<
      MessagesNotifier,
      AsyncValue<List<Message>>,
      int
    >((ref, conversationId) {
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

  MessagesNotifier(this._repo, this._conversationId, this._currentUserId)
    : super(const AsyncValue.loading()) {
    loadMessages();
    _initEcho();
  }

  Future<void> _initEcho() async {
    try {
      final channel = await EchoClient.subscribeToChat(_conversationId);

      channel.bind('App\\Events\\MessageSent').listen((event) {
        try {
          dynamic data = event.data;
          if (data is String) {
            data = jsonDecode(data);
          }

          if (data != null && data['message'] != null) {
            final newMsg = Message.fromJson(data['message']);

            if (newMsg.senderId == _currentUserId) return;

            if (state.hasValue) {
              final currentList = state.value!;
              if (!currentList.any((m) => m.id == newMsg.id)) {
                state = AsyncValue.data([...currentList, newMsg]);
              }
            }

            // Mark as read when receiving a new message
            _repo.markAsRead(_conversationId);
          }
        } catch (e) {
          print('Error parsing WebSocket message: $e');
        }
      });

      channel.bind('App\\Events\\MessagesRead').listen((event) {
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
    } catch (e) {
      print('WebSocket Error: $e');
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

  Future<void> sendMessage(String? content, {String? imagePath}) async {
    try {
      final newMsg = await _repo.sendMessage(
        _conversationId,
        content,
        imagePath: imagePath,
      );
      if (state.hasValue) {
        state = AsyncValue.data([...state.value!, newMsg]);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    EchoClient.disconnect();
    super.dispose();
  }
}
