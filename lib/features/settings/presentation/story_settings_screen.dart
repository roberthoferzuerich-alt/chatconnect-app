import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'settings_provider.dart';

class StorySettingsScreen extends ConsumerWidget {
  const StorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story-Einstellungen'),
        elevation: 0,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          String errMsg = e.toString();
          if (e is DioException && e.response != null) {
            errMsg += '\n\nServer-Details: ${e.response?.data}';
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Fehler: $errMsg',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        },
        data: (settings) {
          final visibility = settings['story_visibility'] ?? 'everyone';
          final muted = List<dynamic>.from(settings['muted_stories'] ?? []);

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Wer kann meine Storys sehen?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              RadioListTile<String>(
                title: const Text('Jeder'),
                subtitle: const Text('Alle Nutzer können deine Storys sehen.'),
                value: 'everyone',
                groupValue: visibility,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).updateSetting('story_visibility', val);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Niemand'),
                subtitle: const Text('Deine Storys sind für niemanden sichtbar.'),
                value: 'nobody',
                groupValue: visibility,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).updateSetting('story_visibility', val);
                  }
                },
              ),
              const Divider(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text(
                  'Stummgeschaltete Storys',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              if (muted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Du hast niemanden stummgeschaltet.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...muted.map((userId) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_off)),
                  title: Text('Nutzer ID: $userId'), // Ideally we fetch the name, but this works for Phase 1
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(settingsProvider.notifier).toggleMutedStory(userId);
                    },
                    child: const Text('Einblenden'),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}
