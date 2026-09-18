import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsSettingsState {
  final bool generateLinkPreviews;
  final bool useAddressBookPhotos;
  final bool keepMutedChatsArchived;
  final bool useSystemEmojis;
  final bool sendWithEnter;
  final double imageUploadSize;
  final double thumbnailSize;

  ChatsSettingsState({
    this.generateLinkPreviews = true,
    this.useAddressBookPhotos = false,
    this.keepMutedChatsArchived = false,
    this.useSystemEmojis = true,
    this.sendWithEnter = false,
    this.imageUploadSize = 1024.0,
    this.thumbnailSize = 100.0,
  });

  ChatsSettingsState copyWith({
    bool? generateLinkPreviews,
    bool? useAddressBookPhotos,
    bool? keepMutedChatsArchived,
    bool? useSystemEmojis,
    bool? sendWithEnter,
    double? imageUploadSize,
    double? thumbnailSize,
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
    );
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
    }
  }
}

final chatsSettingsProvider =
    NotifierProvider<ChatsSettingsNotifier, ChatsSettingsState>(() {
      return ChatsSettingsNotifier();
    });
