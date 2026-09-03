import '../../auth/domain/user_model.dart';

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime? createdAt;
  final User? sender;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.imageUrl,
    this.readAt,
    this.createdAt,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }

  Message copyWith({DateTime? readAt}) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      imageUrl: imageUrl,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      sender: sender,
    );
  }
}
