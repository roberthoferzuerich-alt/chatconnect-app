class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarPath;
  final String? wallpaperUrl;
  final String? about;
  final bool isOnline;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarPath,
    this.wallpaperUrl,
    this.about,
    required this.isOnline,
  });

  String? get fullAvatarUrl {
    final raw = avatarPath;
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    var clean = raw.replaceAll(RegExp(r'^/+'), '');
    while (clean.startsWith('storage/')) {
      clean = clean.substring('storage/'.length).replaceAll(RegExp(r'^/+'), '');
    }
    if (clean.isEmpty) return null;
    return 'https://rhz.internet-box.ch:8443/storage/$clean';
  }

  String? get fullWallpaperUrl {
    final raw = wallpaperUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    var clean = raw.replaceAll(RegExp(r'^/+'), '');
    while (clean.startsWith('storage/')) {
      clean = clean.substring('storage/'.length).replaceAll(RegExp(r'^/+'), '');
    }
    if (clean.isEmpty) return null;
    return 'https://rhz.internet-box.ch:8443/storage/$clean';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    String? rawPath = json['avatar_path'] ?? json['avatar'] ?? json['avatar_url'];
    if (rawPath != null) {
      if (!rawPath.startsWith('http://') && !rawPath.startsWith('https://')) {
        rawPath = rawPath.replaceAll(RegExp(r'^/+'), '');
        while (rawPath!.startsWith('storage/')) {
          rawPath = rawPath.substring('storage/'.length).replaceAll(RegExp(r'^/+'), '');
        }
      }
    }

    String? rawWallpaper = json['wallpaper_url'];
    if (rawWallpaper == null && json['settings'] is Map) {
      rawWallpaper = json['settings']['wallpaper'];
    }

    return User(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatarPath: rawPath,
      wallpaperUrl: rawWallpaper,
      about: json['about'],
      isOnline: json['is_online'] ?? false,
    );
  }
}
