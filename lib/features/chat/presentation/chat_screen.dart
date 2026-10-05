import 'dart:io';
import 'package:app/features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart' as import_dio;
import '../domain/message_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_avatar.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_message_player.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'widgets/connection_indicator.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../settings/presentation/chats_settings_provider.dart';
import 'chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isUploading = false;
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordFilePath;
  bool _emojiShowing = false;
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordFilePath =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(),
          path: _recordFilePath!,
        );
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _isUploading = true;
        });
        await ref
            .read(messagesProvider(widget.conversationId).notifier)
            .sendMessage(null, audioPath: path);
        setState(() {
          _isUploading = false;
        });
        ref.invalidate(conversationsProvider);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isUploading = false;
      });
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    final imageToSend = _attachedImagePath;

    if (text.isEmpty && imageToSend == null) return;

    _msgCtrl.clear();
    setState(() {
      _isUploading = imageToSend != null;
      _attachedImagePath = null;
    });

    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .sendMessage(text, imagePath: imageToSend);
      ref.invalidate(conversationsProvider);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is import_dio.DioException && e.response != null) {
          try {
            errorMsg =
                e.response?.data['message'] ??
                e.response?.data.toString() ??
                e.toString();
          } catch (_) {
            errorMsg = e.response?.data.toString() ?? e.toString();
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backend-Fehler: $errorMsg')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image != null) {
      final size = ref.read(chatsSettingsProvider).imageUploadSize.toInt();
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        maxWidth: size,
        maxHeight: size,
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Bild bearbeiten',
            toolbarColor: Colors.teal,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Bild bearbeiten'),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _attachedImagePath = croppedFile.path;
        });
      }
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Message msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '👏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(
                            messagesProvider(widget.conversationId).notifier,
                          )
                          .toggleReaction(msg.id, emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            if (msg.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Kopieren'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Kopiert!')));
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Löschen',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(messagesProvider(widget.conversationId).notifier)
                        .deleteMessage(msg.id);
                  } catch (e) {
                    String errorMsg = e.toString();
                    if (e is import_dio.DioException && e.response != null) {
                      try {
                        errorMsg =
                            e.response?.data['message'] ??
                            e.response?.data.toString() ??
                            e.toString();
                      } catch (_) {
                        errorMsg = e.response?.data.toString() ?? e.toString();
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backend-Fehler: $errorMsg')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      if (next.hasValue &&
          (previous?.value?.length ?? 0) < next.value!.length) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    final messagesState = ref.watch(messagesProvider(widget.conversationId));
    final currentUser = ref.watch(authStateProvider).value;
    final chatsSettings = ref.watch(chatsSettingsProvider);

    final conversations = ref.watch(conversationsProvider);
    final conversation = conversations.value
        ?.where((c) => c.id == widget.conversationId)
        .firstOrNull;

    // Fallback title generation
    String chatTitle = 'Chat';
    if (conversation != null) {
      if (conversation.isGroup) {
        if (conversation.name != null && conversation.name!.isNotEmpty) {
          chatTitle = conversation.name!;
        } else {
          final otherUsers = conversation.users
              .where((u) => u.id != currentUser?.id)
              .map((u) => u.name)
              .join(', ');
          chatTitle = otherUsers.isNotEmpty ? otherUsers : 'Gruppe';
        }
      } else {
        final otherUser = conversation.users
            .where((u) => u.id != currentUser?.id)
            .firstOrNull;
        chatTitle = otherUser?.name ?? 'Chat';
      }
    }

    final otherUser = conversation?.users
        .where((u) => u.id != currentUser?.id)
        .firstOrNull;

    final invitees = otherUser != null
        ? [ZegoUIKitUser(id: otherUser.id.toString(), name: otherUser.name)]
        : <ZegoUIKitUser>[];

    final hasLocalWallpaper = chatsSettings.wallpaperPath != null &&
        File(chatsSettings.wallpaperPath!).existsSync();
    final hasServerWallpaper = currentUser?.fullWallpaperUrl != null;

    DecorationImage? wallpaperDecoration;
    if (hasLocalWallpaper) {
      wallpaperDecoration = DecorationImage(
        image: FileImage(File(chatsSettings.wallpaperPath!)),
        fit: BoxFit.cover,
      );
    } else if (hasServerWallpaper) {
      wallpaperDecoration = DecorationImage(
        image: CachedNetworkImageProvider(currentUser!.fullWallpaperUrl!),
        fit: BoxFit.cover,
      );
    }

    return PopScope(
      canPop: !_emojiShowing,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_emojiShowing) {
          setState(() {
            _emojiShowing = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              AppAvatar(
                avatarUrl: (conversation != null && !conversation.isGroup)
                    ? otherUser?.fullAvatarUrl
                    : null,
                name: (conversation?.isGroup ?? false)
                    ? (chatTitle)
                    : (otherUser?.name ?? chatTitle),
                isGroup: conversation?.isGroup ?? false,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chatTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            const Center(child: ConnectionIndicator()),
            if (otherUser != null) ...[
              IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.red),
                onPressed: () {
                  final zegoUser = ZegoUIKit().getLocalUser();
                  final inviteeId = otherUser.id.toString();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        zegoUser != null && zegoUser.id.isNotEmpty
                            ? 'Lokal: ${zegoUser.name} (${zegoUser.id}) | Ziel: ${otherUser.name} ($inviteeId)'
                            : 'Fehler: Zego ist NICHT verbunden!',
                      ),
                      duration: const Duration(seconds: 8),
                    ),
                  );
                },
              ),
              ZegoSendCallInvitationButton(
                isVideoCall: false,
                invitees: invitees,
                resourceID: 'zego_data',
                iconSize: const Size(24, 24),
                buttonSize: const Size(48, 48),
              ),
              ZegoSendCallInvitationButton(
                isVideoCall: true,
                invitees: invitees,
                resourceID: 'zego_data',
                iconSize: const Size(24, 24),
                buttonSize: const Size(48, 48),
              ),
            ],
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: wallpaperDecoration == null
                ? Theme.of(context).scaffoldBackgroundColor
                : null,
            image: wallpaperDecoration,
          ),
          child: Column(
            children: [
              Expanded(
                child: messagesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Fehler: $e')),
                data: (messages) {
                  return ListView.builder(
                    reverse: true,
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      final isMe = msg.senderId == currentUser?.id;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showMessageOptions(msg, isMe),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75 > 400
                                  ? 400
                                  : MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.teal.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomRight: isMe
                                    ? Radius.zero
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (msg.imageUrl != null ||
                                    msg.content.isNotEmpty ||
                                    msg.audioUrl != null)
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.start,
                                    children: [
                                      if (msg.imageUrl != null)
                                        GestureDetector(
                                          onTap: () {
                                            final fullUrl =
                                                msg.imageUrl!.startsWith('http')
                                                ? msg.imageUrl!
                                                : 'https://rhz.internet-box.ch:8443/storage/${msg.imageUrl}';
                                            _showFullScreenImage(fullUrl);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxHeight:
                                                    chatsSettings.thumbnailSize,
                                                maxWidth:
                                                    chatsSettings.thumbnailSize,
                                              ),
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    msg.imageUrl!.startsWith(
                                                      'http',
                                                    )
                                                    ? msg.imageUrl!
                                                    : 'https://rhz.internet-box.ch:8443/storage/${msg.imageUrl}',
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                placeholder: (context, url) =>
                                                    const SizedBox(
                                                      height: 50,
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (msg.audioUrl != null)
                                        AudioMessagePlayer(
                                          audioUrl: msg.audioUrl!,
                                          isMe: isMe,
                                        )
                                      else if (msg.content.isNotEmpty)
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.5,
                                          ),
                                          child: Text(
                                            msg.content,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text(
                                          "Audio is null! (Debug)",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                    ],
                                  ),
                                if (msg.reactions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4.0,
                                      bottom: 2.0,
                                    ),
                                    child: Wrap(
                                      spacing: 4,
                                      children: msg.reactions.map((r) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? Colors.teal.shade700
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            r['reaction'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.createdAt != null)
                                      Text(
                                        DateFormat(
                                          'HH:mm',
                                        ).format(msg.createdAt!.toLocal()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                      ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: msg.readAt != null
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
            Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              child: SafeArea(
                child: Column(
                  children: [
                  if (_attachedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_attachedImagePath!),
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: -8,
                                top: -8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _attachedImagePath = null),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        if (!chatsSettings.useSystemEmojis)
                          IconButton(
                            icon: Icon(
                              _emojiShowing
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.teal,
                            ),
                            onPressed: () {
                              setState(() {
                                _emojiShowing = !_emojiShowing;
                                if (_emojiShowing) {
                                  _focusNode.unfocus();
                                } else {
                                  _focusNode.requestFocus();
                                }
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Colors.teal,
                          ),
                          onPressed: _isUploading
                              ? null
                              : _showImageSourceDialog,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: chatsSettings.sendWithEnter
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Nachricht schreiben...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: chatsSettings.sendWithEnter
                                ? (_) => _send()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _msgCtrl,
                          builder: (context, value, child) {
                            final hasText =
                                value.text.trim().isNotEmpty ||
                                _attachedImagePath != null;
                            if (hasText) {
                              return CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                  ),
                                  onPressed: _send,
                                ),
                              );
                            }
                            return GestureDetector(
                              onLongPress: _startRecording,
                              onLongPressUp: _stopRecording,
                              child: CircleAvatar(
                                backgroundColor: _isRecording
                                    ? Colors.red
                                    : Colors.teal,
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
            if (_emojiShowing && !chatsSettings.useSystemEmojis)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  textEditingController: _msgCtrl,
                  config: const Config(
                    emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
