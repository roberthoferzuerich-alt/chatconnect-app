import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:share_plus/share_plus.dart';
import '../data/chat_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';

class NewCallScreen extends ConsumerStatefulWidget {
  const NewCallScreen({super.key});
  @override
  ConsumerState<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends ConsumerState<NewCallScreen> {
  final _searchCtrl = TextEditingController();
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final users = await ref.read(chatRepositoryProvider).searchUsers(query);

      // Filter out current user
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser != null) {
        users.removeWhere((u) => u.id == currentUser.id);
      }

      // Sort alphabetically by name
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() => _users = users);
    } catch (e) {
      // Ignore for MVP
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neuer Anruf')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Name, Nutzername oder Nummer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(
                                left: 24.0,
                                top: 24.0,
                                bottom: 8.0,
                              ),
                              child: Text(
                                'Mehr',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                foregroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                child: const Icon(Icons.refresh),
                              ),
                              title: const Text(
                                'Kontakte aktualisieren',
                                style: TextStyle(fontSize: 16),
                              ),
                              subtitle: const Text(
                                'Fehlt jemand? Versuche es mit Aktualisieren',
                              ),
                              onTap: () {
                                _search(_searchCtrl.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Kontakte wurden aktualisiert',
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                foregroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                child: const Icon(Icons.mail_outline),
                              ),
                              title: const Text(
                                'Zu ChatConnect einladen',
                                style: TextStyle(fontSize: 16),
                              ),
                              onTap: () {
                                Share.share(
                                  'Hey! Lade dir ChatConnect herunter, damit wir chatten und telefonieren können: https://chatconnect.app',
                                );
                              },
                            ),
                          ],
                        );
                      }

                      final user = _users[index];
                      final isFirstOfLetter =
                          index == 0 ||
                          _users[index - 1].name[0].toUpperCase() !=
                              user.name[0].toUpperCase();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isFirstOfLetter)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 24.0,
                                top: 16.0,
                                bottom: 8.0,
                              ),
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              foregroundColor: Colors.indigo.shade900,
                              child: Text(user.name[0].toUpperCase()),
                            ),
                            title: Text(
                              user.name,
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Listener(
                                  onPointerDown: (_) {
                                    ref
                                        .read(chatRepositoryProvider)
                                        .logCall(
                                          receiverId: user.id,
                                          isVideo: false,
                                        );
                                  },
                                  child: ZegoSendCallInvitationButton(
                                    isVideoCall: false,
                                    invitees: [
                                      ZegoUIKitUser(
                                        id: user.id.toString(),
                                        name: user.name,
                                      ),
                                    ],
                                    iconSize: const Size(20, 20),
                                    buttonSize: const Size(40, 40),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Listener(
                                  onPointerDown: (_) {
                                    ref
                                        .read(chatRepositoryProvider)
                                        .logCall(
                                          receiverId: user.id,
                                          isVideo: true,
                                        );
                                  },
                                  child: ZegoSendCallInvitationButton(
                                    isVideoCall: true,
                                    invitees: [
                                      ZegoUIKitUser(
                                        id: user.id.toString(),
                                        name: user.name,
                                      ),
                                    ],
                                    iconSize: const Size(20, 20),
                                    buttonSize: const Size(40, 40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
