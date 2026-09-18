import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'settings_provider.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutz'), elevation: 0),
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
          final lastSeen =
              settings['last_seen_visibility']?.toString() ?? 'everyone';
          final profilePic =
              settings['profile_picture_visibility']?.toString() ?? 'everyone';
          final readReceipts = settings['read_receipts'] == null
              ? true
              : (settings['read_receipts'] == true ||
                    settings['read_receipts'] == 1 ||
                    settings['read_receipts'] == 'true');
          final blocked = settings['blocked_users'] is List
              ? List<dynamic>.from(settings['blocked_users'])
              : [];

          return ListView(
            children: [
              _buildSectionHeader('Sichtbarkeit'),
              ListTile(
                title: const Text('Zuletzt online'),
                subtitle: Text(lastSeen == 'everyone' ? 'Jeder' : 'Niemand'),
                onTap: () => _showVisibilityDialog(
                  context,
                  ref,
                  'last_seen_visibility',
                  lastSeen,
                  'Wer kann deinen "Zuletzt online"-Status sehen?',
                ),
              ),
              ListTile(
                title: const Text('Profilbild'),
                subtitle: Text(profilePic == 'everyone' ? 'Jeder' : 'Niemand'),
                onTap: () => _showVisibilityDialog(
                  context,
                  ref,
                  'profile_picture_visibility',
                  profilePic,
                  'Wer kann dein Profilbild sehen?',
                ),
              ),

              const Divider(),
              _buildSectionHeader('Chats'),
              SwitchListTile(
                title: const Text('Lesebestätigungen (Blaue Haken)'),
                subtitle: const Text(
                  'Wenn du dies deaktivierst, kannst du auch keine Lesebestätigungen von anderen sehen.',
                ),
                value: readReceipts,
                onChanged: (val) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateSetting('read_receipts', val);
                },
                activeColor: Colors.deepPurple,
              ),

              const Divider(),
              _buildSectionHeader('Sicherheit'),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Blockierte Kontakte'),
                subtitle: Text('${blocked.length} Kontakte'),
                onTap: () {
                  // Navigate to blocked contacts screen (Phase 3.2 completed)
                  context.push('/settings_privacy_blocked');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.deepPurple,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showVisibilityDialog(
    BuildContext context,
    WidgetRef ref,
    String key,
    String currentValue,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Jeder'),
                value: 'everyone',
                groupValue: currentValue,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).updateSetting(key, val!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('Niemand'),
                value: 'nobody',
                groupValue: currentValue,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).updateSetting(key, val!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
