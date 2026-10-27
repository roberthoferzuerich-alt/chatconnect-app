import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/domain/user_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';
import '../domain/call_record.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider));
});

class ChatRepository {
  final Dio _dio;
  ChatRepository(this._dio);

  Future<List<User>> searchUsers([String query = '']) async {
    final res = await _dio.get('users', queryParameters: {'q': query});
    return (res.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<List<Conversation>> getConversations() async {
    final res = await _dio.get('conversations');
    return (res.data as List).map((e) => Conversation.fromJson(e)).toList();
  }

  Future<Conversation> startConversation(int userId) async {
    final res = await _dio.post('conversations', data: {'user_id': userId});
    return Conversation.fromJson(res.data);
  }

  Future<Conversation> startGroupConversation(
    List<int> userIds, {
    String? name,
  }) async {
    final res = await _dio.post(
      'conversations/group',
      data: {'user_ids': userIds, 'name': name},
    );
    return Conversation.fromJson(res.data);
  }

  Future<List<Message>> getMessages(int conversationId) async {
    final res = await _dio.get('conversations/$conversationId/messages');
    return (res.data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<List<CallRecord>> getCalls() async {
    final res = await _dio.get('calls');
    return (res.data as List).map((e) => CallRecord.fromJson(e)).toList();
  }

  Future<CallRecord> logCall({
    required int receiverId,
    required bool isVideo,
  }) async {
    final res = await _dio.post(
      'calls',
      data: {
        'receiver_id': receiverId,
        'type': isVideo ? 'video' : 'audio',
        'status': 'completed',
      },
    );
    return CallRecord.fromJson(res.data);
  }

  Future<Message> sendMessage(
    int conversationId,
    String? content, {
    String? imagePath,
    String? audioPath,
    String? documentPath,
    String? documentName,
  }) async {
    FormData? formData;
    if (imagePath != null || audioPath != null || documentPath != null) {
      formData = FormData.fromMap({
        if (content != null && content.isNotEmpty) 'content': content,
        if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
        if (audioPath != null) 'audio': await MultipartFile.fromFile(audioPath),
        if (documentPath != null)
          'document': await MultipartFile.fromFile(
            documentPath,
            filename: documentName,
          ),
        if (documentName != null) 'file_name': documentName,
      });
    }

    final res = await _dio.post(
      'conversations/$conversationId/messages',
      data: formData ?? {'content': content},
    );
    return Message.fromJson(res.data);
  }

  Future<void> markAsRead(int conversationId) async {
    await _dio.post('conversations/$conversationId/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.post('messages/mark-all-read');
  }

  Future<void> deleteMessage(int messageId) async {
    await _dio.post('messages/$messageId/delete');
  }

  Future<Message> updateMessage(int messageId, String content) async {
    final response = await _dio.post(
      'messages/$messageId/update',
      data: {'content': content},
    );
    return Message.fromJson(response.data);
  }

  Future<Message> reactToMessage(int messageId, String emoji) async {
    final response = await _dio.post(
      'messages/$messageId/react',
      data: {'reaction': emoji},
    );
    return Message.fromJson(response.data);
  }

  Future<Message> forwardMessage(
    int messageId,
    int targetConversationId,
  ) async {
    final response = await _dio.post(
      'messages/$messageId/forward',
      data: {'target_conversation_id': targetConversationId},
    );
    return Message.fromJson(response.data);
  }

  Future<List<User>> syncContacts(List<String> phones) async {
    final response = await _dio.post(
      'users/sync-contacts',
      data: {'phones': phones},
    );
    return (response.data as List).map((json) => User.fromJson(json)).toList();
  }

  Future<void> deleteConversation(int id) async {
    await _dio.delete('conversations/$id');
  }
}
