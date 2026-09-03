import '../../auth/domain/user_model.dart';
import 'message_model.dart';

class Conversation {
  final int id;
  final bool isGroup;
  final String? name;
  final List<User> users;
  final Message? lastMessage;
  final DateTime? updatedAt;

  Conversation({
    required this.id,
    required this.isGroup,
    this.name,
    required this.users,
    this.lastMessage,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      isGroup: json['is_group'] ?? false,
      name: json['name'],
      users:
          (json['users'] as List?)?.map((e) => User.fromJson(e)).toList() ?? [],
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
