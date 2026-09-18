import '../../auth/domain/user_model.dart';

class Story {
  final int id;
  final int userId;
  final String mediaPath;
  final String? caption;
  final DateTime expiresAt;
  final DateTime createdAt;
  final User? user;
  final int viewsCount;
  final List<StoryViewer> viewers;

  Story({
    required this.id,
    required this.userId,
    required this.mediaPath,
    this.caption,
    required this.expiresAt,
    required this.createdAt,
    this.user,
    this.viewsCount = 0,
    this.viewers = const [],
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      userId: json['user_id'],
      mediaPath: json['media_path'],
      caption: json['caption'],
      expiresAt: DateTime.parse(json['expires_at']).toLocal(),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      viewsCount: json['views_count'] ?? 0,
      viewers: json['viewers'] != null
          ? (json['viewers'] as List)
                .map((v) => StoryViewer.fromJson(v))
                .toList()
          : [],
    );
  }
}

class StoryViewer {
  final User user;
  final String? reaction;
  final String? message;
  final DateTime createdAt;

  StoryViewer({
    required this.user,
    this.reaction,
    this.message,
    required this.createdAt,
  });

  factory StoryViewer.fromJson(Map<String, dynamic> json) {
    return StoryViewer(
      user: User.fromJson(json['user']),
      reaction: json['reaction'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class UserStoryGroup {
  final User user;
  final List<Story> stories;

  UserStoryGroup({required this.user, required this.stories});

  factory UserStoryGroup.fromJson(Map<String, dynamic> json) {
    return UserStoryGroup(
      user: User.fromJson(json['user']),
      stories: (json['stories'] as List).map((s) => Story.fromJson(s)).toList(),
    );
  }
}
