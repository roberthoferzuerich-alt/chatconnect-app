import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class BlockedContactsScreen extends ConsumerWidget {
  const BlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockierte Kontakte'),
        elevation: 0,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (settings) {
          final blocked = settings['blocked_users'] is List ? List<dynamic>.from(settings['blocked_users']) : [];

          if (blocked.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Keine blockierten Kontakte',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (context, index) {
              final userId = blocked[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.person_off, color: Colors.white),
                ),
                title: Text('Benutzer ID: $userId'),
                trailing: TextButton(
                  onPressed: () {
                    // Remove from blocked list
                    final newList = List.from(blocked)..remove(userId);
                    ref.read(settingsProvider.notifier).updateSetting('blocked_users', newList);
                  },
                  child: const Text('Freigeben', style: TextStyle(color: Colors.green)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
