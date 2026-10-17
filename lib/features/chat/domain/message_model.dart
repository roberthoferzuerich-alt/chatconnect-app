import '../../auth/domain/user_model.dart';

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String? imageUrl;
  final String? audioUrl;
  final String? fileUrl;
  final String? fileName;
  final DateTime? readAt;
  final DateTime? createdAt;
  final User? sender;
  final List<dynamic> reactions;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.imageUrl,
    this.audioUrl,
    this.fileUrl,
    this.fileName,
    this.readAt,
    this.createdAt,
    this.sender,
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      imageUrl: json['image_path'] ?? json['image_url'],
      audioUrl: json['audio_path'] ?? json['audio_url'],
      fileUrl: json['file_path'] ?? json['file_url'],
      fileName: json['file_name'],
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      reactions: json['reactions'] ?? [],
    );
  }

  Message copyWith({
    DateTime? readAt,
    List<dynamic>? reactions,
    String? audioUrl,
    String? fileUrl,
    String? fileName,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      imageUrl: imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      sender: sender,
      reactions: reactions ?? this.reactions,
    );
  }
}
