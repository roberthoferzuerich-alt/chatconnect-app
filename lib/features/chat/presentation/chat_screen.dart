import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
import '../../settings/presentation/widgets/chat_font_size_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
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
  String? _attachedDocumentPath;
  String? _attachedDocumentName;

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
    final docToSend = _attachedDocumentPath;
    final docName = _attachedDocumentName;

    if (text.isEmpty && imageToSend == null && docToSend == null) return;

    _msgCtrl.clear();
    setState(() {
      _isUploading = imageToSend != null || docToSend != null;
      _attachedImagePath = null;
      _attachedDocumentPath = null;
      _attachedDocumentName = null;
    });

    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .sendMessage(
            text,
            imagePath: imageToSend,
            documentPath: docToSend,
            documentName: docName,
          );
      ref.invalidate(conversationsProvider);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            0.0,
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
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Galerie (Foto)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.redAccent,
              ),
              title: const Text('Dokument / PDF / Markdown / 3D-STL'),
              subtitle: const Text(
                'PDF, Markdown (.md), 3D-Modell (.stl/.ctl), Office, ZIP',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'md',
          'markdown',
          'stl',
          'ctl',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'txt',
          'csv',
          'zip',
          'ppt',
          'pptx',
        ],
      );
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Die Datei ist zu groß (maximal 50 MB erlaubt).'),
              ),
            );
          }
          return;
        }
        setState(() {
          _attachedDocumentPath = file.path;
          _attachedDocumentName = file.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _openDocument(String fileUrl, String? fileName) async {
    final fullUrl = fileUrl.startsWith('http')
        ? fileUrl
        : 'https://rhz.internet-box.ch:8443/storage/${fileUrl.replaceFirst(RegExp(r"^/?storage/"), "").replaceFirst(RegExp(r"^/"), "")}';
    final displayFileName =
        (fileName != null && fileName.isNotEmpty)
            ? fileName
            : fullUrl.split('/').last;
    final lowerName = displayFileName.toLowerCase();
    final isMarkdown =
        lowerName.endsWith('.md') || lowerName.endsWith('.markdown');
    final isStl = lowerName.endsWith('.stl') || lowerName.endsWith('.ctl');

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMarkdown
                  ? 'Öffne „$displayFileName“ im Markdown-Viewer...'
                  : (isStl
                        ? 'Öffne „$displayFileName“ im 3D-STL-Browser...'
                        : 'Lade „$displayFileName“ herunter...'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$displayFileName';
      await import_dio.Dio().download(fullUrl, savePath);

      if (isMarkdown) {
        final mdContent = await File(savePath).readAsString();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(
                title: Text(displayFileName),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Datei teilen / speichern',
                    onPressed: () {
                      Share.shareXFiles([XFile(savePath)], text: displayFileName);
                    },
                  ),
                ],
              ),
              body: Markdown(
                data: mdContent,
                selectable: true,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        );
        return;
      }

      if (isStl) {
        final bytes = await File(savePath).readAsBytes();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => _StlViewerScreen(
              fileName: displayFileName,
              filePath: savePath,
              bytes: bytes,
            ),
          ),
        );
        return;
      }

      await Share.shareXFiles([XFile(savePath)], text: displayFileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Öffnen des Dokuments: $e')),
        );
      }
    }
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
              0.0,
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
        chatTitle = otherUser != null
            ? otherUser.name
            : '${currentUser?.name ?? "Ich"} (Eigene Dateien)';
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
                    ? (otherUser?.fullAvatarUrl ?? currentUser?.fullAvatarUrl)
                    : null,
                name: (conversation?.isGroup ?? false)
                    ? (chatTitle)
                    : (otherUser?.name ?? currentUser?.name ?? chatTitle),
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
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'font_size') {
                  showChatFontSizeDialog(context);
                } else if (value == 'chat_settings') {
                  context.push('/settings_chats');
                } else if (value == 'user_guide') {
                  context.push('/user_guide');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'font_size',
                  child: Text('Chat-Schriftgröße'),
                ),
                const PopupMenuItem(
                  value: 'chat_settings',
                  child: Text('Chat-Einstellungen'),
                ),
                const PopupMenuItem(
                  value: 'user_guide',
                  child: Text('Benutzeranleitung'),
                ),
              ],
            ),
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
                                    msg.fileUrl != null ||
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
                                      if (msg.fileUrl != null)
                                        InkWell(
                                          onTap: () => _openDocument(
                                            msg.fileUrl!,
                                            msg.fileName,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 260,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? Colors.teal.shade200
                                                        .withValues(alpha: 0.45)
                                                  : Colors.white.withValues(
                                                      alpha: 0.85,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.black12,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: (msg.fileName ?? '')
                                                            .toLowerCase()
                                                            .endsWith('.pdf')
                                                        ? Colors.red.shade100
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.md',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.markdown',
                                                                    ))
                                                        ? Colors.indigo.shade100
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.stl',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.ctl',
                                                                    ))
                                                        ? Colors.lightBlue.shade100
                                                        : Colors.teal.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    (msg.fileName ?? '')
                                                            .toLowerCase()
                                                            .endsWith('.pdf')
                                                        ? Icons.picture_as_pdf
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.md',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.markdown',
                                                                    ))
                                                        ? Icons.article_outlined
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.stl',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.ctl',
                                                                    ))
                                                        ? Icons.view_in_ar
                                                        : Icons.description,
                                                    color: (msg.fileName ?? '')
                                                            .toLowerCase()
                                                            .endsWith('.pdf')
                                                        ? Colors.red.shade700
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.md',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.markdown',
                                                                    ))
                                                        ? Colors.indigo.shade700
                                                        : ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.stl',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.ctl',
                                                                    ))
                                                        ? Colors.lightBlue.shade800
                                                        : Colors.teal.shade700,
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        msg.fileName ??
                                                            msg.fileUrl!
                                                                .split('/')
                                                                .last,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      Text(
                                                        ((msg.fileName ?? '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.md',
                                                                    ) ||
                                                                (msg.fileName ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                      '.markdown',
                                                                    ))
                                                            ? 'Im Markdown-Viewer öffnen'
                                                            : ((msg.fileName ??
                                                                            '')
                                                                        .toLowerCase()
                                                                        .endsWith(
                                                                          '.stl',
                                                                        ) ||
                                                                    (msg.fileName ??
                                                                            '')
                                                                        .toLowerCase()
                                                                        .endsWith(
                                                                          '.ctl',
                                                                        ))
                                                            ? 'Im 3D-STL-Browser öffnen'
                                                            : 'Tippen zum Öffnen',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.open_in_new,
                                                  size: 16,
                                                  color: Colors.black54,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (msg.audioUrl != null)
                                        AudioMessagePlayer(
                                          audioUrl: msg.audioUrl!,
                                          isMe: isMe,
                                        ),
                                      if (msg.content.isNotEmpty)
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
                                            style: TextStyle(
                                              fontSize: chatsSettings.chatFontSize,
                                              color: Colors.black87,
                                            ),
                                          ),
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
                  if (_attachedDocumentPath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _attachedDocumentName ?? 'Dokument',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _attachedDocumentPath = null;
                                _attachedDocumentName = null;
                              }),
                            ),
                          ],
                        ),
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
                                _attachedImagePath != null ||
                                _attachedDocumentPath != null;
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
    ),
  );
}
}

class _StlTriangle {
  final double v1x, v1y, v1z;
  final double v2x, v2y, v2z;
  final double v3x, v3y, v3z;
  final double nx, ny, nz;

  const _StlTriangle(
    this.v1x,
    this.v1y,
    this.v1z,
    this.v2x,
    this.v2y,
    this.v2z,
    this.v3x,
    this.v3y,
    this.v3z,
    this.nx,
    this.ny,
    this.nz,
  );
}

class _StlViewerScreen extends StatefulWidget {
  final String fileName;
  final String filePath;
  final Uint8List bytes;

  const _StlViewerScreen({
    required this.fileName,
    required this.filePath,
    required this.bytes,
  });

  @override
  State<_StlViewerScreen> createState() => _StlViewerScreenState();
}

class _StlViewerScreenState extends State<_StlViewerScreen> {
  List<_StlTriangle> _triangles = [];
  double _rotX = -0.55;
  double _rotY = 0.65;
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  double _baseZoom = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _wireframe = false;
  bool _showGrid = true;
  Color _modelColor = const Color(0xFF38BDF8);
  String _stats = 'Analysiere 3D-Modell...';
  double _modelRadius = 50.0;

  @override
  void initState() {
    super.initState();
    _parseStl();
  }

  void _parseStl() {
    final data = widget.bytes;
    final rawTriangles = <_StlTriangle>[];
    bool isBinary = false;

    if (data.length >= 84) {
      final bd = ByteData.sublistView(data);
      final count = bd.getUint32(80, Endian.little);
      final expected = 84 + count * 50;
      if (expected == data.length) {
        isBinary = true;
      } else {
        final header = ascii.decode(
          data.sublist(0, math.min(80, data.length)),
          allowInvalid: true,
        );
        if (!header.trimLeft().toLowerCase().startsWith('solid') &&
            count > 0 &&
            expected <= data.length + 512) {
          isBinary = true;
        }
      }

      if (isBinary) {
        int offset = 84;
        for (int i = 0; i < count; i++) {
          if (offset + 50 > data.length) break;
          final nx = bd.getFloat32(offset, Endian.little);
          final ny = bd.getFloat32(offset + 4, Endian.little);
          final nz = bd.getFloat32(offset + 8, Endian.little);
          final v1x = bd.getFloat32(offset + 12, Endian.little);
          final v1y = bd.getFloat32(offset + 16, Endian.little);
          final v1z = bd.getFloat32(offset + 20, Endian.little);
          final v2x = bd.getFloat32(offset + 24, Endian.little);
          final v2y = bd.getFloat32(offset + 28, Endian.little);
          final v2z = bd.getFloat32(offset + 32, Endian.little);
          final v3x = bd.getFloat32(offset + 36, Endian.little);
          final v3y = bd.getFloat32(offset + 40, Endian.little);
          final v3z = bd.getFloat32(offset + 44, Endian.little);
          rawTriangles.add(
            _StlTriangle(v1x, v1z, -v1y, v2x, v2z, -v2y, v3x, v3z, -v3y, nx, nz, -ny),
          );
          offset += 50;
        }
      }
    }

    if (!isBinary) {
      final text = utf8.decode(data, allowMalformed: true);
      final reg = RegExp(
        r'vertex\s+([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)\s+([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)\s+([+\-]?\d*\.?\d+(?:[eE][+\-]?\d+)?)',
        caseSensitive: false,
      );
      final matches = reg.allMatches(text).toList();
      for (int i = 0; i + 2 < matches.length; i += 3) {
        final v1x = double.tryParse(matches[i].group(1)!) ?? 0;
        final v1y = double.tryParse(matches[i].group(2)!) ?? 0;
        final v1z = double.tryParse(matches[i].group(3)!) ?? 0;
        final v2x = double.tryParse(matches[i + 1].group(1)!) ?? 0;
        final v2y = double.tryParse(matches[i + 1].group(2)!) ?? 0;
        final v2z = double.tryParse(matches[i + 1].group(3)!) ?? 0;
        final v3x = double.tryParse(matches[i + 2].group(1)!) ?? 0;
        final v3y = double.tryParse(matches[i + 2].group(2)!) ?? 0;
        final v3z = double.tryParse(matches[i + 2].group(3)!) ?? 0;
        rawTriangles.add(
          _StlTriangle(v1x, v1z, -v1y, v2x, v2z, -v2y, v3x, v3z, -v3y, 0, 1, 0),
        );
      }
    }

    if (rawTriangles.isEmpty) {
      setState(() {
        _stats = 'Keine 3D-Geometrie gefunden';
      });
      return;
    }

    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final t in rawTriangles) {
      minX = math.min(minX, math.min(t.v1x, math.min(t.v2x, t.v3x)));
      minY = math.min(minY, math.min(t.v1y, math.min(t.v2y, t.v3y)));
      minZ = math.min(minZ, math.min(t.v1z, math.min(t.v2z, t.v3z)));
      maxX = math.max(maxX, math.max(t.v1x, math.max(t.v2x, t.v3x)));
      maxY = math.max(maxY, math.max(t.v1y, math.max(t.v2y, t.v3y)));
      maxZ = math.max(maxZ, math.max(t.v1z, math.max(t.v2z, t.v3z)));
    }

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;
    final dx = maxX - minX;
    final dy = maxY - minY;
    final dz = maxZ - minZ;
    final radius = math.max(1.0, math.sqrt(dx * dx + dy * dy + dz * dz) / 2);

    // Für flüssiges Rendering auf Smartphones ggf. auf max. 8000 Dreiecke abtasten
    final step = math.max(1, (rawTriangles.length / 8000).ceil());
    final centered = <_StlTriangle>[];
    for (int i = 0; i < rawTriangles.length; i += step) {
      final t = rawTriangles[i];
      final ux = (t.v2x - t.v1x), uy = (t.v2y - t.v1y), uz = (t.v2z - t.v1z);
      final vx = (t.v3x - t.v1x), vy = (t.v3y - t.v1y), vz = (t.v3z - t.v1z);
      double nx = uy * vz - uz * vy;
      double ny = uz * vx - ux * vz;
      double nz = ux * vy - uy * vx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 0) {
        nx /= len;
        ny /= len;
        nz /= len;
      }
      centered.add(
        _StlTriangle(
          t.v1x - cx,
          t.v1y - cy,
          t.v1z - cz,
          t.v2x - cx,
          t.v2y - cy,
          t.v2z - cz,
          t.v3x - cx,
          t.v3y - cy,
          t.v3z - cz,
          nx,
          ny,
          nz,
        ),
      );
    }

    setState(() {
      _triangles = centered;
      _modelRadius = radius;
      _stats =
          '${rawTriangles.length} Dreiecke · ${dx.toStringAsFixed(1)} × ${dz.toStringAsFixed(1)} × ${dy.toStringAsFixed(1)} mm';
    });
  }

  void _setView(String view) {
    setState(() {
      _pan = Offset.zero;
      _zoom = 1.0;
      if (view == 'front') {
        _rotX = 0;
        _rotY = 0;
      } else if (view == 'top') {
        _rotX = -math.pi / 2;
        _rotY = 0;
      } else if (view == 'side') {
        _rotX = 0;
        _rotY = math.pi / 2;
      } else {
        _rotX = -0.55;
        _rotY = 0.65;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, style: const TextStyle(fontSize: 15)),
            Text(
              _stats,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '3D-Datei teilen / speichern',
            onPressed: () {
              Share.shareXFiles([XFile(widget.filePath)], text: widget.fileName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolBtn('Iso (3D)', () => _setView('iso')),
                  _buildToolBtn('Vorne', () => _setView('front')),
                  _buildToolBtn('Oben', () => _setView('top')),
                  _buildToolBtn('Seite', () => _setView('side')),
                  const SizedBox(width: 6),
                  _buildToolBtn(
                    'Drahtgitter',
                    () => setState(() => _wireframe = !_wireframe),
                    active: _wireframe,
                  ),
                  _buildToolBtn(
                    'Gitter',
                    () => setState(() => _showGrid = !_showGrid),
                    active: _showGrid,
                  ),
                  const SizedBox(width: 8),
                  _buildColorDot(const Color(0xFF38BDF8)),
                  _buildColorDot(const Color(0xFF14B8A6)),
                  _buildColorDot(const Color(0xFFCBD5E1)),
                  _buildColorDot(const Color(0xFFFB923C)),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onScaleStart: (d) {
                _baseZoom = _zoom;
                _lastFocalPoint = d.focalPoint;
              },
              onScaleUpdate: (d) {
                setState(() {
                  if (d.pointerCount == 1) {
                    final delta = d.focalPoint - _lastFocalPoint;
                    _rotY += delta.dx * 0.01;
                    _rotX = (_rotX + delta.dy * 0.01).clamp(
                      -math.pi / 2,
                      math.pi / 2,
                    );
                  } else {
                    _zoom = (_baseZoom * d.scale).clamp(0.25, 6.0);
                    _pan += d.focalPoint - _lastFocalPoint;
                  }
                  _lastFocalPoint = d.focalPoint;
                });
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: _StlPainter(
                  triangles: _triangles,
                  modelRadius: _modelRadius,
                  rotX: _rotX,
                  rotY: _rotY,
                  zoom: _zoom,
                  pan: _pan,
                  wireframe: _wireframe,
                  showGrid: _showGrid,
                  baseColor: _modelColor,
                ),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            width: double.infinity,
            child: const Text(
              '1 Finger: Drehen · 2 Finger: Verschieben & Zoomen',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn(String label, VoidCallback onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.lightBlue.shade600 : const Color(0xFF334155),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final selected = _modelColor == color;
    return GestureDetector(
      onTap: () => setState(() => _modelColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _StlPainter extends CustomPainter {
  final List<_StlTriangle> triangles;
  final double modelRadius;
  final double rotX;
  final double rotY;
  final double zoom;
  final Offset pan;
  final bool wireframe;
  final bool showGrid;
  final Color baseColor;

  _StlPainter({
    required this.triangles,
    required this.modelRadius,
    required this.rotX,
    required this.rotY,
    required this.zoom,
    required this.pan,
    required this.wireframe,
    required this.showGrid,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + pan.dx;
    final cy = size.height / 2 + pan.dy;
    final scale =
        (math.min(size.width, size.height) * 0.38 / modelRadius) * zoom;

    final cosY = math.cos(rotY), sinY = math.sin(rotY);
    final cosX = math.cos(rotX), sinX = math.sin(rotX);

    Offset project(double x, double y, double z) {
      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      final y2 = y * cosX - z1 * sinX;
      return Offset(cx + x1 * scale, cy - y2 * scale);
    }

    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white12
        ..strokeWidth = 1;
      final g = modelRadius * 1.2;
      for (int i = -5; i <= 5; i++) {
        final pos = (i / 5) * g;
        canvas.drawLine(
          project(-g, -modelRadius * 0.6, pos),
          project(g, -modelRadius * 0.6, pos),
          gridPaint,
        );
        canvas.drawLine(
          project(pos, -modelRadius * 0.6, -g),
          project(pos, -modelRadius * 0.6, g),
          gridPaint,
        );
      }
    }

    final projected = <({
      Offset p1,
      Offset p2,
      Offset p3,
      double zOrder,
      double shade,
    })>[];

    for (final t in triangles) {
      final x1 = t.v1x * cosY + t.v1z * sinY;
      final z1 = -t.v1x * sinY + t.v1z * cosY;
      final y1 = t.v1y * cosX - z1 * sinX;
      final zz1 = t.v1y * sinX + z1 * cosX;

      final x2 = t.v2x * cosY + t.v2z * sinY;
      final z2 = -t.v2x * sinY + t.v2z * cosY;
      final y2 = t.v2y * cosX - z2 * sinX;
      final zz2 = t.v2y * sinX + z2 * cosX;

      final x3 = t.v3x * cosY + t.v3z * sinY;
      final z3 = -t.v3x * sinY + t.v3z * cosY;
      final y3 = t.v3y * cosX - z3 * sinX;
      final zz3 = t.v3y * sinX + z3 * cosX;

      final nx1 = t.nx * cosY + t.nz * sinY;
      final nz1 = -t.nx * sinY + t.nz * cosY;
      final ny2 = t.ny * cosX - nz1 * sinX;
      final nz2 = t.ny * sinX + nz1 * cosX;

      final light = (nx1 * 0.4 + ny2 * 0.6 + nz2.abs() * 0.7).clamp(0.2, 1.0);

      projected.add((
        p1: Offset(cx + x1 * scale, cy - y1 * scale),
        p2: Offset(cx + x2 * scale, cy - y2 * scale),
        p3: Offset(cx + x3 * scale, cy - y3 * scale),
        zOrder: (zz1 + zz2 + zz3) / 3,
        shade: light,
      ));
    }

    projected.sort((a, b) => a.zOrder.compareTo(b.zOrder));

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = wireframe ? baseColor : Colors.black26;

    for (final tri in projected) {
      final path = Path()
        ..moveTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..lineTo(tri.p3.dx, tri.p3.dy)
        ..close();

      if (!wireframe) {
        fillPaint.color = Color.fromARGB(
          255,
          ((baseColor.r * 255) * tri.shade).round().clamp(0, 255),
          ((baseColor.g * 255) * tri.shade).round().clamp(0, 255),
          ((baseColor.b * 255) * tri.shade).round().clamp(0, 255),
        );
        canvas.drawPath(path, fillPaint);
      } else {
        canvas.drawPath(path, wirePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StlPainter oldDelegate) => true;
}

