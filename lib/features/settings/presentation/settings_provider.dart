import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, Map<String, dynamic>>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getSettings();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final repo = ref.read(settingsRepositoryProvider);
    
    // Optimistic update
    final current = state.value ?? {};
    final updated = Map<String, dynamic>.from(current)..[key] = value;
    state = AsyncValue.data(updated);

    try {
      final serverSettings = await repo.updateSettings({key: value});
      state = AsyncValue.data(serverSettings);
    } catch (e, st) {
      // Revert on failure
      state = AsyncValue.error(e, st);
      ref.invalidateSelf();
    }
  }

  Future<void> toggleMutedStory(int userId) async {
    final current = state.value ?? {};
    List<dynamic> muted = List.from(current['muted_stories'] ?? []);
    
    if (muted.contains(userId)) {
      muted.remove(userId);
    } else {
      muted.add(userId);
    }
    
    await updateSetting('muted_stories', muted);
  }
}
