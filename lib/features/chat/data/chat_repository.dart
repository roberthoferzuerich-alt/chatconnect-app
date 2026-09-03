import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/domain/user_model.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

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

  Future<List<Message>> getMessages(int conversationId) async {
    final res = await _dio.get('conversations/$conversationId/messages');
    return (res.data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<Message> sendMessage(
    int conversationId,
    String? content, {
    String? imagePath,
  }) async {
    FormData? formData;
    if (imagePath != null) {
      formData = FormData.fromMap({
        if (content != null && content.isNotEmpty) 'content': content,
        'image': await MultipartFile.fromFile(imagePath),
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

  Future<void> deleteMessage(int messageId) async {
    await _dio.delete('messages/$messageId');
  }
}
