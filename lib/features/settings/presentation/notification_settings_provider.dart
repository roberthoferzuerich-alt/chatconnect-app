import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsState {
  final bool messageTones;
  final bool vibration;
  final bool highPriority;
  final bool reactionNotifications;

  const NotificationSettingsState({
    this.messageTones = true,
    this.vibration = true,
    this.highPriority = true,
    this.reactionNotifications = true,
  });

  NotificationSettingsState copyWith({
    bool? messageTones,
    bool? vibration,
    bool? highPriority,
    bool? reactionNotifications,
  }) {
    return NotificationSettingsState(
      messageTones: messageTones ?? this.messageTones,
      vibration: vibration ?? this.vibration,
      highPriority: highPriority ?? this.highPriority,
      reactionNotifications:
          reactionNotifications ?? this.reactionNotifications,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  static const _keyMessageTones = 'notif_message_tones';
  static const _keyVibration = 'notif_vibration';
  static const _keyHighPriority = 'notif_high_priority';
  static const _keyReaction = 'notif_reaction';

  late SharedPreferences _prefs;

  @override
  NotificationSettingsState build() {
    _init();
    return const NotificationSettingsState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = NotificationSettingsState(
      messageTones: _prefs.getBool(_keyMessageTones) ?? true,
      vibration: _prefs.getBool(_keyVibration) ?? true,
      highPriority: _prefs.getBool(_keyHighPriority) ?? true,
      reactionNotifications: _prefs.getBool(_keyReaction) ?? true,
    );
  }

  void toggleMessageTones(bool value) {
    _prefs.setBool(_keyMessageTones, value);
    state = state.copyWith(messageTones: value);
  }

  void toggleVibration(bool value) {
    _prefs.setBool(_keyVibration, value);
    state = state.copyWith(vibration: value);
  }

  void toggleHighPriority(bool value) {
    _prefs.setBool(_keyHighPriority, value);
    state = state.copyWith(highPriority: value);
  }

  void toggleReactionNotifications(bool value) {
    _prefs.setBool(_keyReaction, value);
    state = state.copyWith(reactionNotifications: value);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      () {
        return NotificationSettingsNotifier();
      },
    );
