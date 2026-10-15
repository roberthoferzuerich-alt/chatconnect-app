import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_provider.dart';

class ChatsSettingsState {
  final bool generateLinkPreviews;
  final bool useAddressBookPhotos;
  final bool keepMutedChatsArchived;
  final bool useSystemEmojis;
  final bool sendWithEnter;
  final double imageUploadSize;
  final double thumbnailSize;
  final double chatFontSize;
  final String? wallpaperPath;

  ChatsSettingsState({
    this.generateLinkPreviews = true,
    this.useAddressBookPhotos = false,
    this.keepMutedChatsArchived = false,
    this.useSystemEmojis = true,
    this.sendWithEnter = false,
    this.imageUploadSize = 1024.0,
    this.thumbnailSize = 100.0,
    this.chatFontSize = 16.0,
    this.wallpaperPath,
  });

  ChatsSettingsState copyWith({
    bool? generateLinkPreviews,
    bool? useAddressBookPhotos,
    bool? keepMutedChatsArchived,
    bool? useSystemEmojis,
    bool? sendWithEnter,
    double? imageUploadSize,
    double? thumbnailSize,
    double? chatFontSize,
    String? wallpaperPath,
    bool clearWallpaper = false,
  }) {
    return ChatsSettingsState(
      generateLinkPreviews: generateLinkPreviews ?? this.generateLinkPreviews,
      useAddressBookPhotos: useAddressBookPhotos ?? this.useAddressBookPhotos,
      keepMutedChatsArchived:
          keepMutedChatsArchived ?? this.keepMutedChatsArchived,
      useSystemEmojis: useSystemEmojis ?? this.useSystemEmojis,
      sendWithEnter: sendWithEnter ?? this.sendWithEnter,
      imageUploadSize: imageUploadSize ?? this.imageUploadSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      chatFontSize: chatFontSize ?? this.chatFontSize,
      wallpaperPath: clearWallpaper ? null : (wallpaperPath ?? this.wallpaperPath),
    );
  }
}

class ChatsSettingsNotifier extends Notifier<ChatsSettingsState> {
  @override
  ChatsSettingsState build() {
    _loadSettings();
    return ChatsSettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = ChatsSettingsState(
      generateLinkPreviews: prefs.getBool('generateLinkPreviews') ?? true,
      useAddressBookPhotos: prefs.getBool('useAddressBookPhotos') ?? false,
      keepMutedChatsArchived: prefs.getBool('keepMutedChatsArchived') ?? false,
      useSystemEmojis: prefs.getBool('useSystemEmojis') ?? true,
      sendWithEnter: prefs.getBool('sendWithEnter') ?? false,
      imageUploadSize: prefs.getDouble('imageUploadSize') ?? 1024.0,
      thumbnailSize: prefs.getDouble('thumbnailSize') ?? 100.0,
      chatFontSize: prefs.getDouble('chatFontSize') ?? 16.0,
      wallpaperPath: prefs.getString('chat_wallpaper_path'),
    );
  }

  Future<void> setWallpaper(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_wallpaper_path', path);
    state = state.copyWith(wallpaperPath: path);

    // Sync to backend asynchronously
    try {
      final dio = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'wallpaper': await MultipartFile.fromFile(path),
      });
      await dio.post('auth/profile/wallpaper', data: formData);
      ref.invalidate(authStateProvider);
    } catch (_) {
      // Local wallpaper is always preserved offline
    }
  }

  Future<void> resetWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_wallpaper_path');
    state = state.copyWith(clearWallpaper: true);

    try {
      final dio = ref.read(apiClientProvider);
      await dio.delete('auth/profile/wallpaper');
      ref.invalidate(authStateProvider);
    } catch (_) {}
  }

  Future<void> updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    switch (key) {
      case 'generateLinkPreviews':
        state = state.copyWith(generateLinkPreviews: value);
        break;
      case 'useAddressBookPhotos':
        state = state.copyWith(useAddressBookPhotos: value);
        break;
      case 'keepMutedChatsArchived':
        state = state.copyWith(keepMutedChatsArchived: value);
        break;
      case 'useSystemEmojis':
        state = state.copyWith(useSystemEmojis: value);
        break;
      case 'sendWithEnter':
        state = state.copyWith(sendWithEnter: value);
        break;
    }
  }

  Future<void> updateDoubleSetting(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
    if (key == 'imageUploadSize') {
      state = state.copyWith(imageUploadSize: value);
    } else if (key == 'thumbnailSize') {
      state = state.copyWith(thumbnailSize: value);
    } else if (key == 'chatFontSize') {
      state = state.copyWith(chatFontSize: value);
    }
  }
}

final chatsSettingsProvider =
    NotifierProvider<ChatsSettingsNotifier, ChatsSettingsState>(() {
      return ChatsSettingsNotifier();
    });
