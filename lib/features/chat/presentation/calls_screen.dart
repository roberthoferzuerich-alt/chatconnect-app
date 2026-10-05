import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_avatar.dart';
import 'chat_providers.dart';
import '../../auth/presentation/auth_provider.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh calls when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(callsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final callsState = ref.watch(callsProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Anrufe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(callsProvider),
          ),
        ],
      ),
      body: callsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Fehler: $e')),
        data: (calls) {
          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Anrufe',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deine Anrufliste wird hier bald erscheinen.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final call = calls[index];
              final isOutgoing = call.callerId == currentUser?.id;
              final otherUser = isOutgoing ? call.receiver : call.caller;
              final otherName = otherUser?.name ?? 'Unbekannt';
              final avatarUrl = otherUser?.fullAvatarUrl;

              final timeString = DateFormat(
                'dd.MM.yyyy HH:mm',
              ).format(call.startedAt);
              final iconColor = isOutgoing ? Colors.green : Colors.redAccent;
              final iconData = isOutgoing
                  ? Icons.call_made
                  : Icons.call_received;
              final callTypeIcon = call.type == 'video'
                  ? Icons.videocam
                  : Icons.phone;

              return ListTile(
                leading: AppAvatar(
                  avatarUrl: avatarUrl,
                  name: otherName,
                  radius: 20,
                ),
                title: Text(
                  otherName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    Icon(iconData, size: 16, color: iconColor),
                    const SizedBox(width: 4),
                    Text(
                      timeString,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                trailing: Icon(callTypeIcon, color: Colors.blue),
                onTap: () {
                  // We could directly call from here if we had the ZegoButton wrapped,
                  // but for now we navigate to the user search / new call screen.
                  context.push('/new_call');
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_call),
        onPressed: () {
          context.push('/new_call');
        },
      ),
    );
  }
}
