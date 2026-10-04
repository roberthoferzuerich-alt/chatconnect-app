class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarPath;
  final String? about;
  final bool isOnline;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarPath,
    this.about,
    required this.isOnline,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatarPath: json['avatar_path'] ?? json['avatar'],
      about: json['about'],
      isOnline: json['is_online'] ?? false,
    );
  }
}
