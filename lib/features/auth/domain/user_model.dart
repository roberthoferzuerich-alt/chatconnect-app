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

  String? get fullAvatarUrl {
    final raw = avatarPath;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final clean = raw.replaceFirst(RegExp(r'^/?storage/'), '').replaceFirst(RegExp(r'^/'), '');
    return 'https://rhz.internet-box.ch:8443/storage/$clean';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatarPath: json['avatar_url'] ?? json['avatar_path'] ?? json['avatar'],
      about: json['about'],
      isOnline: json['is_online'] ?? false,
    );
  }
}
