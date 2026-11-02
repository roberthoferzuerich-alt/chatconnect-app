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
  Message? _replyingToMsg;
  String _replyingToSender = '';
  bool _showInChatSearch = false;
  String _inChatSearchQuery = '';
  bool _showStarredOnly = false;
  final _inChatSearchCtrl = TextEditingController();

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
    _inChatSearchCtrl.dispose();
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
    final rawText = _msgCtrl.text.trim();
    final imageToSend = _attachedImagePath;
    final docToSend = _attachedDocumentPath;
    final docName = _attachedDocumentName;

    if (rawText.isEmpty && imageToSend == null && docToSend == null) return;

    String text = rawText;
    if (_replyingToMsg != null) {
      final cleanSnippet = _stripQuotePrefix(_replyingToMsg!.content)
          .replaceAll('\n', ' ')
          .trim();
      final fallback = _replyingToMsg!.fileName ??
          (_replyingToMsg!.imageUrl != null ? '📷 Bild' : 'Nachricht');
      final snippet = (cleanSnippet.isNotEmpty ? cleanSnippet : fallback);
      final shortSnippet = snippet.length > 80
          ? '${snippet.substring(0, 80)}…'
          : snippet;
      text = '> 💬 @$_replyingToSender: "$shortSnippet"\n$rawText';
    }

    _msgCtrl.clear();
    setState(() {
      _isUploading = imageToSend != null || docToSend != null;
      _attachedImagePath = null;
      _attachedDocumentPath = null;
      _attachedDocumentName = null;
      _replyingToMsg = null;
      _replyingToSender = '';
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
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF00A884)),
              ),
              title: const Text(
                '✨ KI-Bildgenerator (Assistent)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884)),
              ),
              subtitle: const Text('Bild per KI erstellen & direkt hierher senden'),
              onTap: () {
                Navigator.pop(context);
                context.push('/assistant', extra: widget.conversationId);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.view_in_ar, color: Colors.lightBlue),
              ),
              title: const Text(
                '🧊 3D-Modell-Generator (.STL)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
              ),
              subtitle: const Text(
                '3D-Modell per Text erstellen, im 3D-Viewer prüfen & senden',
              ),
              onTap: () {
                Navigator.pop(context);
                _showStlGeneratorDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.poll_outlined, color: Colors.amber.shade800),
              ),
              title: Text(
                '📊 Interaktive Umfrage erstellen',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              subtitle: const Text(
                'Frage & Antwortoptionen zum Live-Abstimmen im Chat senden',
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreatePollDialog();
              },
            ),
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
          '7z',
          'z',
          'rar',
          'tar',
          'gz',
          'tgz',
          'bz2',
          'xz',
          'jar',
          'mcpack',
          'mcworld',
          'mcaddon',
          'json',
          '3mf',
          'obj',
          'gcode',
          'scad',
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
    final displayFileName = (fileName != null && fileName.isNotEmpty)
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
                      Share.shareXFiles([
                        XFile(savePath),
                      ], text: displayFileName);
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

      final isZipArchive =
          lowerName.endsWith('.zip') ||
          lowerName.endsWith('.jar') ||
          lowerName.endsWith('.mcpack') ||
          lowerName.endsWith('.mcworld') ||
          lowerName.endsWith('.mcaddon') ||
          lowerName.endsWith('.3mf');

      if (isZipArchive) {
        final bytes = await File(savePath).readAsBytes();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => _ArchiveInspectorScreen(
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

  String _stripQuotePrefix(String raw) {
    final match = RegExp(
      r'^> 💬 @([^:]+): "([^"]*)"\r?\n([\s\S]*)$',
    ).firstMatch(raw);
    return match != null ? (match.group(3) ?? '') : raw;
  }

  ({String? author, String? quoted, String body}) _parseQuotedContent(
    String raw,
  ) {
    final match = RegExp(
      r'^> 💬 @([^:]+): "([^"]*)"\r?\n([\s\S]*)$',
    ).firstMatch(raw);
    if (match != null) {
      return (
        author: match.group(1),
        quoted: match.group(2),
        body: match.group(3) ?? '',
      );
    }
    return (author: null, quoted: null, body: raw);
  }

  void _showMessageOptions(Message msg, bool isMe, String senderName) {
    final isStarred = ref.read(starredMessageIdsProvider).contains(msg.id);
    final isPinned =
        ref.read(pinnedMessagesProvider)[widget.conversationId] == msg.id;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '🎉', '🔥'].map((emoji) {
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
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00A884)),
              title: const Text('Antworten / Zitieren'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingToMsg = msg;
                  _replyingToSender = senderName;
                });
                _focusNode.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward, color: Colors.teal),
              title: const Text('Nachricht / Datei weiterleiten ↪️'),
              onTap: () {
                Navigator.pop(context);
                _showForwardMessageDialog(msg);
              },
            ),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: Colors.amber.shade800,
              ),
              title: Text(
                isPinned
                    ? 'Anpinnen oben im Chat aufheben 📌'
                    : 'Oben im Chat anpinnen 📌',
              ),
              onTap: () async {
                Navigator.pop(context);
                final nowPinned = await ref
                    .read(pinnedMessagesProvider.notifier)
                    .togglePin(widget.conversationId, msg.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nowPinned
                            ? '📌 Nachricht oben im Chat angepinnt'
                            : '📌 Anpinnen aufgehoben',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                isStarred ? Icons.star : Icons.star_border,
                color: Colors.amber.shade700,
              ),
              title: Text(
                isStarred
                    ? 'Stern-Markierung entfernen'
                    : 'Mit Stern markieren ⭐',
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(starredMessageIdsProvider.notifier).toggle(msg.id);
              },
            ),
            if (msg.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Kopieren'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                    ClipboardData(text: _stripQuotePrefix(msg.content)),
                  );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Kopiert!')));
                },
              ),
            if (isMe && msg.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.teal),
                title: const Text('Nachricht bearbeiten ✏️'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMessageDialog(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Löschen', style: TextStyle(color: Colors.red)),
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

  void _showEditMessageDialog(Message msg) {
    final parsed = _parseQuotedContent(msg.content);
    final quoteHeader = (parsed.author != null && parsed.quoted != null)
        ? '> 💬 @${parsed.author}: "${parsed.quoted}"\n'
        : '';
    final cleanBody = parsed.body.replaceFirst(
      RegExp(r'\s*\(bearbeitet\)\s*$'),
      '',
    );
    final editCtrl = TextEditingController(text: cleanBody);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ Nachricht bearbeiten'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nachrichtentext...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nextBody = editCtrl.text.trim();
              Navigator.pop(ctx);
              if (nextBody.isEmpty || nextBody == cleanBody.trim()) return;
              try {
                await ref
                    .read(messagesProvider(widget.conversationId).notifier)
                    .editMessage(msg.id, '$quoteHeader$nextBody');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bearbeiten fehlgeschlagen: $e')),
                  );
                }
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showCreatePollDialog() {
    final questionCtrl = TextEditingController();
    final optionCtrls = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    final pollEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void applyPreset(String q, List<String> opts) {
            questionCtrl.text = q;
            while (optionCtrls.length < opts.length) {
              optionCtrls.add(TextEditingController());
            }
            for (var i = 0; i < optionCtrls.length; i++) {
              optionCtrls[i].text = i < opts.length ? opts[i] : '';
            }
            setSheetState(() {});
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.poll, color: Colors.amber),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📊 Interaktive Umfrage erstellen',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Echtzeit-Abstimmung zwischen WebApp & Android-App',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        backgroundColor: const Color(0xFF1E293B),
                        label: const Text(
                          '📅 Termin',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        onPressed: () => applyPreset(
                          'Wann passt euch das nächste Treffen am besten?',
                          [
                            'Freitag Abend (19:00 Uhr)',
                            'Samstag Nachmittag',
                            'Sonntag gemütlich',
                          ],
                        ),
                      ),
                      ActionChip(
                        backgroundColor: const Color(0xFF1E293B),
                        label: const Text(
                          '🍕 Essen',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        onPressed: () => applyPreset(
                          'Was bestellen wir heute zum Essen?',
                          [
                            '🍕 Pizza & Pasta',
                            '🍔 Burger & Pommes',
                            '🍣 Asiatisch / Sushi',
                          ],
                        ),
                      ),
                      ActionChip(
                        backgroundColor: const Color(0xFF1E293B),
                        label: const Text(
                          '🧊 3D-Farbe',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        onPressed: () => applyPreset(
                          'In welcher Filament-Farbe soll das 3D-Modell gedruckt werden?',
                          [
                            '⚫ Anthrazit / Schwarz (PLA)',
                            '⚪ Weiß / Silber (PETG)',
                            '🟢 Smaragdgrün / Türkis',
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: questionCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Frage oder Thema der Umfrage',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(optionCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            pollEmojis[i],
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: optionCtrls[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Antwort-Option ${i + 1}',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (optionCtrls.length < 5)
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          optionCtrls.add(TextEditingController());
                        });
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Color(0xFF00D4AA),
                        size: 18,
                      ),
                      label: const Text(
                        'Weitere Option hinzufügen (max. 5)',
                        style: TextStyle(
                          color: Color(0xFF00D4AA),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('Umfrage in Chat senden'),
                      onPressed: () async {
                        final q = questionCtrl.text.trim();
                        final opts = optionCtrls
                            .map((c) => c.text.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        if (q.isEmpty || opts.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bitte eine Frage und mindestens 2 Optionen eingeben.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final lines = <String>['📊 [UMFRAGE] $q'];
                        for (var i = 0; i < opts.length && i < 5; i++) {
                          lines.add('${pollEmojis[i]} ${opts[i]}');
                        }
                        await ref
                            .read(
                              messagesProvider(widget.conversationId).notifier,
                            )
                            .sendMessage(lines.join('\n'));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showForwardMessageDialog(Message msg) {
    final convos = ref.read(conversationsProvider).value ?? const [];
    final currentUser = ref.read(authStateProvider).value;
    String searchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = convos.where((c) {
            if (searchFilter.isEmpty) return true;
            final other = c.users
                .where((u) => u.id != currentUser?.id)
                .firstOrNull;
            final label = c.isGroup
                ? (c.name ?? 'Gruppe')
                : (other?.name ??
                      '${currentUser?.name ?? "Ich"} (Ich / Eigene Dateien)');
            return label.toLowerCase().contains(searchFilter.toLowerCase());
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.forward, color: Color(0xFF00A884)),
                      SizedBox(width: 8),
                      Text(
                        '↪️ Nachricht / Datei weiterleiten an...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Kontakt oder Gruppe suchen...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setSheetState(() => searchFilter = v),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final targetConvo = filtered[idx];
                        final other = targetConvo.users
                            .where((u) => u.id != currentUser?.id)
                            .firstOrNull;
                        final isSelf = !targetConvo.isGroup && other == null;
                        final title = targetConvo.isGroup
                            ? (targetConvo.name ?? 'Gruppe')
                            : (isSelf
                                  ? '${currentUser?.name ?? "Ich"} (Ich / Eigene Dateien)'
                                  : (other?.name ?? 'Unbekannt'));
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelf
                                ? Colors.teal.shade700
                                : const Color(0xFF00A884),
                            child: Icon(
                              targetConvo.isGroup
                                  ? Icons.group
                                  : (isSelf ? Icons.folder_special : Icons.person),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            isSelf
                                ? 'In persönlicher Ablage speichern'
                                : (targetConvo.isGroup
                                      ? 'Gruppenchat'
                                      : 'Direktnachricht'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A884),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.send, size: 14),
                            label: const Text(
                              'Senden',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await ref
                                    .read(chatRepositoryProvider)
                                    .forwardMessage(msg.id, targetConvo.id);
                                ref.invalidate(
                                  messagesProvider(targetConvo.id),
                                );
                                ref.invalidate(conversationsProvider);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '↪️ Weitergeleitet an $title',
                                    ),
                                    action: targetConvo.id !=
                                            widget.conversationId
                                        ? SnackBarAction(
                                            label: 'Chat öffnen',
                                            onPressed: () {
                                              context.pushReplacement(
                                                '/chat/${targetConvo.id}',
                                              );
                                            },
                                          )
                                        : null,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Weiterleiten fehlgeschlagen: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChatMediaGallerySheet(List<Message> allMessages) {
    final photos = allMessages.where((m) => m.imageUrl != null).toList();
    final stlFiles = allMessages.where((m) {
      final name = (m.fileName ?? m.fileUrl ?? '').toLowerCase();
      return m.fileUrl != null &&
          (name.endsWith('.stl') || name.endsWith('.ctl'));
    }).toList();
    final docs = allMessages.where((m) {
      final name = (m.fileName ?? m.fileUrl ?? '').toLowerCase();
      return m.fileUrl != null &&
          !(name.endsWith('.stl') || name.endsWith('.ctl'));
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.perm_media,
                      color: Color(0xFF00A884),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '🗂️ Medien, Dokumente & 3D-Modelle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: const Color(0xFF00A884),
                indicatorColor: const Color(0xFF00A884),
                tabs: [
                  Tab(text: '📷 Fotos (${photos.length})'),
                  Tab(text: '📄 Dokumente (${docs.length})'),
                  Tab(text: '🧊 3D-STL (${stlFiles.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    photos.isEmpty
                        ? const Center(
                            child: Text('Noch keine Fotos in diesem Chat.'),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: photos.length,
                            itemBuilder: (context, i) {
                              final m = photos[i];
                              final fullUrl = m.imageUrl!.startsWith('http')
                                  ? m.imageUrl!
                                  : 'https://rhz.internet-box.ch:8443/storage/${m.imageUrl}';
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showFullScreenImage(fullUrl);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: fullUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                    docs.isEmpty
                        ? const Center(
                            child: Text('Noch keine Dokumente in diesem Chat.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final m = docs[i];
                              final fName =
                                  m.fileName ?? m.fileUrl!.split('/').last;
                              return ListTile(
                                leading: const Icon(
                                  Icons.description,
                                  color: Color(0xFF00A884),
                                ),
                                title: Text(
                                  fName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  m.createdAt == null
                                      ? ''
                                      : DateFormat(
                                          'dd.MM.yyyy HH:mm',
                                        ).format(m.createdAt!.toLocal()),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(Icons.open_in_new, size: 18),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _openDocument(m.fileUrl!, m.fileName);
                                },
                              );
                            },
                          ),
                    stlFiles.isEmpty
                        ? const Center(
                            child: Text(
                              'Noch keine 3D-STL-Modelle in diesem Chat.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: stlFiles.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final m = stlFiles[i];
                              final fName =
                                  m.fileName ?? m.fileUrl!.split('/').last;
                              return ListTile(
                                leading: const Icon(
                                  Icons.view_in_ar,
                                  color: Colors.cyan,
                                ),
                                title: Text(
                                  fName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: const Text(
                                  'Tippen für interaktive 3D-Vorschau',
                                  style: TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(
                                  Icons.threed_rotation,
                                  size: 18,
                                  color: Colors.cyan,
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _openDocument(m.fileUrl!, m.fileName);
                                },
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
    );
  }

  Widget _buildPollWidget(Message msg, int? currentUserId) {
    final parsed = _parseQuotedContent(msg.content);
    final rawLines = parsed.body
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) return Text(msg.content);

    final question = rawLines.first.replaceFirst('📊 [UMFRAGE]', '').trim();
    final pollEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣'];
    final options = <(String emoji, String label)>[];

    for (var i = 1; i < rawLines.length && options.length < 5; i++) {
      final line = rawLines[i];
      final emo = pollEmojis[options.length];
      final cleaned = line.startsWith(emo)
          ? line.substring(emo.length).trim()
          : line;
      options.add((emo, cleaned));
    }

    int totalVotes = 0;
    final counts = <String, int>{};
    final myVotes = <String>{};
    for (final (emo, _) in options) {
      final c = msg.reactions.where((r) => r.emoji == emo).length;
      counts[emo] = c;
      totalVotes += c;
      if (currentUserId != null &&
          msg.reactions.any(
            (r) => r.emoji == emo && r.userId == currentUserId,
          )) {
        myVotes.add(emo);
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00A884).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 INTERAKTIVE UMFRAGE · TIPPE ZUM ABSTIMMEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF008069),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...options.map((opt) {
            final emo = opt.$1;
            final label = opt.$2;
            final count = counts[emo] ?? 0;
            final pct = totalVotes > 0 ? (count / totalVotes) : 0.0;
            final voted = myVotes.contains(emo);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  ref
                      .read(messagesProvider(widget.conversationId).notifier)
                      .toggleReaction(msg.id, emo);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: voted
                        ? const Color(0xFF00A884).withValues(alpha: 0.14)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: voted
                          ? const Color(0xFF00A884)
                          : Colors.grey.shade300,
                      width: voted ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emo, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: voted
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '${(pct * 100).round()}% ($count)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF008069),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00A884),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            '$totalVotes ${totalVotes == 1 ? "Stimme" : "Stimmen"} insgesamt',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  void _showStlGeneratorDialog() {
    final promptCtrl = TextEditingController(
      text: 'Mittelschnauzer liegend auf Sockel',
    );
    double scaleFactor = 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final presets = [
            ('🐶 Mittelschnauzer', 'Mittelschnauzer liegend auf Sockel'),
            ('🏷️ Schlüsselanhänger', 'Schlüsselanhänger ROBI'),
            ('⚙️ Zahnrad 20Z', 'Zahnrad 20 Zähne'),
            ('🚀 Rakete', 'Weltraum-Rakete mit Flügeln'),
            ('🏰 Ritterburg', 'Mittelalterliche Ritterburg mit 4 Türmen'),
            ('❤️ Herz-Dose', 'Herz-Schatulle 3D'),
            ('🎲 Spielwürfel', 'Spielwürfel mit Augen'),
          ];

          Future<void> runGenerate({required bool sendToChat}) async {
            final prompt = promptCtrl.text.trim();
            if (prompt.isEmpty) return;
            Navigator.pop(ctx);
            final result = _StlProceduralGenerator.generateBinaryStl(
              prompt,
              scaleFactor: scaleFactor,
            );
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/${result.fileName}';
            await File(filePath).writeAsBytes(result.bytes);

            if (!mounted) return;
            if (sendToChat) {
              setState(() {
                _attachedDocumentPath = filePath;
                _attachedDocumentName = result.fileName;
                if (_msgCtrl.text.trim().isEmpty) {
                  _msgCtrl.text = '🧊 3D-Modell: $prompt';
                }
              });
              await _send();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _StlViewerScreen(
                    fileName: result.fileName,
                    filePath: filePath,
                    bytes: result.bytes,
                  ),
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.view_in_ar,
                        color: Color(0xFF00D4AA),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3D-Modell-Generator (.STL)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Erzeugt druckfertige Binär-STL-Modelle direkt auf dem Smartphone',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: promptCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Was soll als 3D-Modell erstellt werden?',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      label: Text(
                        p.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      onPressed: () =>
                          setSheetState(() => promptCtrl.text = p.$2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Modell-Größe:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: scaleFactor,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        activeColor: const Color(0xFF00D4AA),
                        label: '${(scaleFactor * 100).round()}%',
                        onChanged: (v) => setSheetState(() => scaleFactor = v),
                      ),
                    ),
                    Text(
                      '${(scaleFactor * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFF00D4AA),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D4AA),
                          side: const BorderSide(color: Color(0xFF00D4AA)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => runGenerate(sendToChat: false),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('3D-Vorschau'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => runGenerate(sendToChat: true),
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('In Chat senden'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

    final hasLocalWallpaper =
        chatsSettings.wallpaperPath != null &&
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
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showChatMediaGallerySheet(
              messagesState.value ?? const <Message>[],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AppAvatar(
                    avatarUrl: (conversation != null && !conversation.isGroup)
                        ? (otherUser?.fullAvatarUrl ??
                              currentUser?.fullAvatarUrl)
                        : null,
                    name: (conversation?.isGroup ?? false)
                        ? (chatTitle)
                        : (otherUser?.name ?? currentUser?.name ?? chatTitle),
                    isGroup: conversation?.isGroup ?? false,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(chatTitle, overflow: TextOverflow.ellipsis),
                        const Text(
                          'Tippen für Medien, Dokumente & 3D-STL',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            IconButton(
              icon: Icon(
                _showInChatSearch ? Icons.search_off : Icons.search,
                color: _showInChatSearch ? const Color(0xFF00A884) : null,
              ),
              tooltip: 'Im Chat suchen',
              onPressed: () {
                setState(() {
                  _showInChatSearch = !_showInChatSearch;
                  if (!_showInChatSearch) {
                    _inChatSearchQuery = '';
                    _inChatSearchCtrl.clear();
                  }
                });
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'search_chat') {
                  setState(() => _showInChatSearch = !_showInChatSearch);
                } else if (value == 'media_gallery') {
                  _showChatMediaGallerySheet(
                    messagesState.value ?? const <Message>[],
                  );
                } else if (value == 'create_poll') {
                  _showCreatePollDialog();
                } else if (value == 'starred_filter') {
                  setState(() => _showStarredOnly = !_showStarredOnly);
                } else if (value == 'assistant') {
                  context.push('/assistant', extra: widget.conversationId);
                } else if (value == 'font_size') {
                  showChatFontSizeDialog(context);
                } else if (value == 'chat_settings') {
                  context.push('/settings_chats');
                } else if (value == 'user_guide') {
                  context.push('/user_guide');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'media_gallery',
                  child: Row(
                    children: [
                      Icon(
                        Icons.perm_media,
                        color: Color(0xFF00A884),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('🗂️ Medien, Dokumente & 3D-Modelle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'create_poll',
                  child: Row(
                    children: [
                      Icon(Icons.poll, color: Colors.amber, size: 20),
                      SizedBox(width: 10),
                      Text('📊 Umfrage erstellen'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'starred_filter',
                  child: Row(
                    children: [
                      Icon(
                        _showStarredOnly ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _showStarredOnly
                            ? 'Alle Nachrichten zeigen'
                            : '⭐ Nur Stern-Favoriten',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assistant',
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF00A884),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'KI-Bildgenerator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ],
                  ),
                ),
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
              Builder(
                builder: (context) {
                  final pinnedMap = ref.watch(pinnedMessagesProvider);
                  final pinnedId = pinnedMap[widget.conversationId];
                  final allMsgs = messagesState.value;
                  if (pinnedId == null || allMsgs == null) {
                    return const SizedBox.shrink();
                  }
                  final pinnedMsg = allMsgs
                      .where((m) => m.id == pinnedId)
                      .firstOrNull;
                  if (pinnedMsg == null) return const SizedBox.shrink();
                  final previewText = pinnedMsg.content.trim().isNotEmpty
                      ? _parseQuotedContent(
                          pinnedMsg.content,
                        ).body.replaceAll('\n', ' ')
                      : (pinnedMsg.fileName ??
                            (pinnedMsg.imageUrl != null
                                ? '📷 Foto'
                                : '🎵 Sprachnachricht'));
                  return Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.push_pin,
                          size: 17,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final idx = allMsgs.indexWhere(
                                (m) => m.id == pinnedMsg.id,
                              );
                              if (idx != -1 && _scrollCtrl.hasClients) {
                                final reverseIdx = allMsgs.length - 1 - idx;
                                _scrollCtrl.animateTo(
                                  (reverseIdx * 72.0).clamp(
                                    0.0,
                                    _scrollCtrl.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '📌 Angepinnte Nachricht',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 17),
                          tooltip: 'Nicht mehr anpinnen',
                          onPressed: () {
                            ref
                                .read(pinnedMessagesProvider.notifier)
                                .unpin(widget.conversationId);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_showInChatSearch || _showStarredOnly)
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF00A884),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _inChatSearchCtrl,
                          autofocus: _showInChatSearch,
                          decoration: const InputDecoration(
                            hintText: 'Nachrichten im Chat durchsuchen...',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onChanged: (val) =>
                              setState(() => _inChatSearchQuery = val.trim()),
                        ),
                      ),
                      if (_showStarredOnly)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.star,
                              size: 15,
                              color: Colors.amber,
                            ),
                            label: const Text(
                              'Stern-Filter',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () =>
                                setState(() => _showStarredOnly = false),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _showInChatSearch = false;
                            _showStarredOnly = false;
                            _inChatSearchQuery = '';
                            _inChatSearchCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: messagesState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Fehler: $e')),
                  data: (allMessages) {
                    final starredIds = ref.watch(starredMessageIdsProvider);
                    final q = _inChatSearchQuery.toLowerCase();
                    final messages = allMessages.where((m) {
                      if (_showStarredOnly && !starredIds.contains(m.id)) {
                        return false;
                      }
                      if (q.isNotEmpty) {
                        final textMatch = m.content.toLowerCase().contains(q);
                        final fileMatch = (m.fileName ?? '')
                            .toLowerCase()
                            .contains(q);
                        return textMatch || fileMatch;
                      }
                      return true;
                    }).toList();

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg.senderId == currentUser?.id;
                        final isStarred = starredIds.contains(msg.id);
                        final senderName = isMe
                            ? (currentUser?.name ?? 'Ich')
                            : (msg.sender?.name ?? otherUser?.name ?? chatTitle);
                        final parsedQuote = _parseQuotedContent(msg.content);

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () =>
                                _showMessageOptions(msg, isMe, senderName),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.82 >
                                        420
                                    ? 420
                                    : MediaQuery.of(context).size.width * 0.82,
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
                                                  msg.imageUrl!.startsWith(
                                                    'http',
                                                  )
                                                  ? msg.imageUrl!
                                                  : 'https://rhz.internet-box.ch:8443/storage/${msg.imageUrl}';
                                              _showFullScreenImage(fullUrl);
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxHeight: chatsSettings
                                                      .thumbnailSize,
                                                  maxWidth: chatsSettings
                                                      .thumbnailSize,
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
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context).size.width * 0.7 > 260
                                                    ? 260
                                                    : MediaQuery.of(context).size.width * 0.7,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? Colors.teal.shade200
                                                          .withValues(
                                                            alpha: 0.45,
                                                          )
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
                                                      color:
                                                          (msg.fileName ?? '')
                                                              .toLowerCase()
                                                              .endsWith('.pdf')
                                                          ? Colors.red.shade100
                                                          : ((msg.fileName ??
                                                                        '')
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
                                                          ? Colors
                                                                .indigo
                                                                .shade100
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
                                                          ? Colors
                                                                .lightBlue
                                                                .shade100
                                                          : Colors
                                                                .teal
                                                                .shade100,
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
                                                          : ((msg.fileName ??
                                                                        '')
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
                                                          ? Icons
                                                                .article_outlined
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
                                                          ? Icons.view_in_ar
                                                          : Icons.description,
                                                      color:
                                                          (msg.fileName ?? '')
                                                              .toLowerCase()
                                                              .endsWith('.pdf')
                                                          ? Colors.red.shade700
                                                          : ((msg.fileName ??
                                                                        '')
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
                                                          ? Colors
                                                                .indigo
                                                                .shade700
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
                                                          ? Colors
                                                                .lightBlue
                                                                .shade800
                                                          : Colors
                                                                .teal
                                                                .shade700,
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
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .black87,
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
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .black54,
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
                                                  0.62,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (parsedQuote.author !=
                                                        null &&
                                                    parsedQuote.quoted != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.06,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: const Border(
                                                        left: BorderSide(
                                                          color: Color(
                                                            0xFF00A884,
                                                          ),
                                                          width: 3.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '↩️ ${parsedQuote.author}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFF008069,
                                                                ),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          parsedQuote.quoted!,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (parsedQuote.body.isNotEmpty)
                                                  if (parsedQuote.body
                                                      .trimLeft()
                                                      .startsWith(
                                                        '📊 [UMFRAGE]',
                                                      ))
                                                    _buildPollWidget(
                                                      msg,
                                                      currentUser?.id,
                                                    )
                                                  else if (parsedQuote.body
                                                      .trimLeft()
                                                      .startsWith(
                                                        '↪️ Weitergeleitet:',
                                                      ))
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          '↪️ Weitergeleitet',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                              0xFF008069,
                                                            ),
                                                          ),
                                                        ),
                                                        if (parsedQuote.body
                                                            .trimLeft()
                                                            .replaceFirst(
                                                              '↪️ Weitergeleitet:',
                                                              '',
                                                            )
                                                            .trim()
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            parsedQuote.body
                                                                .trimLeft()
                                                                .replaceFirst(
                                                                  '↪️ Weitergeleitet:',
                                                                  '',
                                                                )
                                                                .trim(),
                                                            style: TextStyle(
                                                              fontSize:
                                                                  chatsSettings
                                                                      .chatFontSize,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    )
                                                  else
                                                    Text(
                                                      parsedQuote.body,
                                                      style: TextStyle(
                                                        fontSize: chatsSettings
                                                            .chatFontSize,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                              ],
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
                                      child: Builder(
                                        builder: (context) {
                                          final counts = <String, int>{};
                                          for (final r in msg.reactions) {
                                            final emo = r is Map
                                                ? (r['reaction']?.toString() ??
                                                      '')
                                                : r.toString();
                                            if (emo.isNotEmpty) {
                                              counts[emo] =
                                                  (counts[emo] ?? 0) + 1;
                                            }
                                          }
                                          return Wrap(
                                            spacing: 4,
                                            children: counts.entries.map((e) {
                                              return GestureDetector(
                                                onTap: () => ref
                                                    .read(
                                                      messagesProvider(
                                                        widget.conversationId,
                                                      ).notifier,
                                                    )
                                                    .toggleReaction(
                                                      msg.id,
                                                      e.key,
                                                    ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.black12,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    e.value > 1
                                                        ? '${e.key} ${e.value}'
                                                        : e.key,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isStarred) ...[
                                        Icon(
                                          Icons.star,
                                          size: 13,
                                          color: Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 3),
                                      ],
                                      if (msg.createdAt != null)
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(msg.createdAt!.toLocal()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
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
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.95),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (_replyingToMsg != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A884).withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              left: BorderSide(
                                color: Color(0xFF00A884),
                                width: 4,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 18,
                                color: Color(0xFF00A884),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Antwort an $_replyingToSender',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFF008069),
                                      ),
                                    ),
                                    Text(
                                      _stripQuotePrefix(
                                            _replyingToMsg!.content,
                                          ).isNotEmpty
                                          ? _stripQuotePrefix(
                                              _replyingToMsg!.content,
                                            )
                                          : (_replyingToMsg!.fileName ??
                                                '📷 Medien-Anhang'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() {
                                  _replyingToMsg = null;
                                  _replyingToSender = '';
                                }),
                              ),
                            ],
                          ),
                        ),
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
                                      onTap: () => setState(
                                        () => _attachedImagePath = null,
                                      ),
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
  String _renderMode = 'solid'; // solid, wireframe, xray, rainbow, normals
  bool _showGrid = true;
  bool _showBBox = false;
  Color _modelColor = const Color(0xFF00D4AA);
  String _stats = 'Analysiere 3D-Modell...';
  double _modelRadius = 50.0;
  int _totalTriangleCount = 0;
  double _volumeCm3 = 0.0;
  double _areaCm2 = 0.0;
  double _dimX = 0.0, _dimY = 0.0, _dimZ = 0.0;

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
            _StlTriangle(
              v1x,
              v1z,
              -v1y,
              v2x,
              v2z,
              -v2y,
              v3x,
              v3z,
              -v3y,
              nx,
              nz,
              -ny,
            ),
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

    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;
    double signedVolumeMm3 = 0.0;
    double surfaceAreaMm2 = 0.0;

    for (final t in rawTriangles) {
      minX = math.min(minX, math.min(t.v1x, math.min(t.v2x, t.v3x)));
      minY = math.min(minY, math.min(t.v1y, math.min(t.v2y, t.v3y)));
      minZ = math.min(minZ, math.min(t.v1z, math.min(t.v2z, t.v3z)));
      maxX = math.max(maxX, math.max(t.v1x, math.max(t.v2x, t.v3x)));
      maxY = math.max(maxY, math.max(t.v1y, math.max(t.v2y, t.v3y)));
      maxZ = math.max(maxZ, math.max(t.v1z, math.max(t.v2z, t.v3z)));

      // Signed volume of tetrahedron (v1, v2, v3, origin)
      signedVolumeMm3 +=
          (t.v1x * (t.v2y * t.v3z - t.v2z * t.v3y) -
              t.v1y * (t.v2x * t.v3z - t.v2z * t.v3x) +
              t.v1z * (t.v2x * t.v3y - t.v2y * t.v3x)) /
          6.0;

      final ux = t.v2x - t.v1x, uy = t.v2y - t.v1y, uz = t.v2z - t.v1z;
      final vx = t.v3x - t.v1x, vy = t.v3y - t.v1y, vz = t.v3z - t.v1z;
      final cxCross = uy * vz - uz * vy;
      final cyCross = uz * vx - ux * vz;
      final czCross = ux * vy - uy * vx;
      surfaceAreaMm2 +=
          0.5 *
          math.sqrt(cxCross * cxCross + cyCross * cyCross + czCross * czCross);
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
      _totalTriangleCount = rawTriangles.length;
      _volumeCm3 = signedVolumeMm3.abs() / 1000.0;
      _areaCm2 = surfaceAreaMm2 / 100.0;
      _dimX = dx;
      _dimY = dy;
      _dimZ = dz;
      _stats =
          '${rawTriangles.length} Δ · ${_volumeCm3.toStringAsFixed(2)} cm³ · ${dx.toStringAsFixed(1)}×${dz.toStringAsFixed(1)}×${dy.toStringAsFixed(1)} mm';
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
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131929),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.fileName,
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D4AA),
                    ),
                  ),
                ),
              ],
            ),
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
              Share.shareXFiles([
                XFile(widget.filePath),
              ], text: widget.fileName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF131929),
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
                    'Solid',
                    () => setState(() => _renderMode = 'solid'),
                    active: _renderMode == 'solid',
                  ),
                  _buildToolBtn(
                    'Drahtgitter',
                    () => setState(() => _renderMode = 'wireframe'),
                    active: _renderMode == 'wireframe',
                  ),
                  _buildToolBtn(
                    'Röntgen',
                    () => setState(() => _renderMode = 'xray'),
                    active: _renderMode == 'xray',
                  ),
                  _buildToolBtn(
                    'Z-Höhe 🌈',
                    () => setState(() => _renderMode = 'rainbow'),
                    active: _renderMode == 'rainbow',
                  ),
                  _buildToolBtn(
                    'Normalen',
                    () => setState(() => _renderMode = 'normals'),
                    active: _renderMode == 'normals',
                  ),
                  const SizedBox(width: 6),
                  _buildToolBtn(
                    'Maß-Box',
                    () => setState(() => _showBBox = !_showBBox),
                    active: _showBBox,
                  ),
                  _buildToolBtn(
                    'Gitter',
                    () => setState(() => _showGrid = !_showGrid),
                    active: _showGrid,
                  ),
                  const SizedBox(width: 8),
                  _buildColorDot(const Color(0xFF00D4AA)),
                  _buildColorDot(const Color(0xFF38BDF8)),
                  _buildColorDot(const Color(0xFFFB923C)),
                  _buildColorDot(const Color(0xFFA78BFA)),
                  _buildColorDot(const Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
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
                      renderMode: _renderMode,
                      showGrid: _showGrid,
                      showBBox: _showBBox,
                      dimX: _dimX,
                      dimY: _dimY,
                      dimZ: _dimZ,
                      baseColor: _modelColor,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131929).withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📐 ${_dimX.toStringAsFixed(1)} × ${_dimZ.toStringAsFixed(1)} × ${_dimY.toStringAsFixed(1)} mm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🧊 Volumen: ${_volumeCm3.toStringAsFixed(2)} cm³  •  Oberfläche: ${_areaCm2.toStringAsFixed(1)} cm²',
                            style: const TextStyle(
                              color: Color(0xFF00D4AA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🔺 $_totalTriangleCount Dreiecke',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF131929),
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

  Widget _buildToolBtn(
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00A884) : const Color(0xFF232F46),
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
  final String renderMode;
  final bool showGrid;
  final bool showBBox;
  final double dimX, dimY, dimZ;
  final Color baseColor;

  _StlPainter({
    required this.triangles,
    required this.modelRadius,
    required this.rotX,
    required this.rotY,
    required this.zoom,
    required this.pan,
    required this.renderMode,
    required this.showGrid,
    required this.showBBox,
    required this.dimX,
    required this.dimY,
    required this.dimZ,
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

    final projected =
        <
          ({
            Offset p1,
            Offset p2,
            Offset p3,
            double zOrder,
            double shade,
            double avgY,
            double nx,
            double ny,
            double nz,
          })
        >[];

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
        avgY: (t.v1y + t.v2y + t.v3y) / 3,
        nx: t.nx,
        ny: t.ny,
        nz: t.nz,
      ));
    }

    projected.sort((a, b) => a.zOrder.compareTo(b.zOrder));

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..color = renderMode == 'wireframe' ? baseColor : Colors.black26;

    final halfY = math.max(1.0, dimY / 2);

    for (final tri in projected) {
      final path = Path()
        ..moveTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..lineTo(tri.p3.dx, tri.p3.dy)
        ..close();

      if (renderMode == 'wireframe') {
        canvas.drawPath(path, wirePaint);
      } else if (renderMode == 'xray') {
        fillPaint.color = baseColor.withValues(alpha: 0.22 * tri.shade);
        canvas.drawPath(path, fillPaint);
      } else if (renderMode == 'rainbow') {
        final tNorm = ((tri.avgY + halfY) / (2 * halfY)).clamp(0.0, 1.0);
        final c = HSVColor.fromAHSV(
          1.0,
          (1.0 - tNorm) * 240.0,
          0.85,
          tri.shade,
        ).toColor();
        fillPaint.color = c;
        canvas.drawPath(path, fillPaint);
      } else if (renderMode == 'normals') {
        fillPaint.color = Color.fromARGB(
          255,
          (((tri.nx * 0.5 + 0.5) * 255) * tri.shade).round().clamp(0, 255),
          (((tri.ny * 0.5 + 0.5) * 255) * tri.shade).round().clamp(0, 255),
          (((tri.nz * 0.5 + 0.5) * 255) * tri.shade).round().clamp(0, 255),
        );
        canvas.drawPath(path, fillPaint);
      } else {
        fillPaint.color = Color.fromARGB(
          255,
          ((baseColor.r * 255) * tri.shade).round().clamp(0, 255),
          ((baseColor.g * 255) * tri.shade).round().clamp(0, 255),
          ((baseColor.b * 255) * tri.shade).round().clamp(0, 255),
        );
        canvas.drawPath(path, fillPaint);
      }
    }

    if (showBBox && dimX > 0) {
      final hx = dimX / 2, hy = dimY / 2, hz = dimZ / 2;
      final corners = [
        project(-hx, -hy, -hz),
        project(hx, -hy, -hz),
        project(hx, -hy, hz),
        project(-hx, -hy, hz),
        project(-hx, hy, -hz),
        project(hx, hy, -hz),
        project(hx, hy, hz),
        project(-hx, hy, hz),
      ];
      final edges = [
        [0, 1],
        [1, 2],
        [2, 3],
        [3, 0],
        [4, 5],
        [5, 6],
        [6, 7],
        [7, 4],
        [0, 4],
        [1, 5],
        [2, 6],
        [3, 7],
      ];
      final boxPaint = Paint()
        ..color = const Color(0xFF00D4AA).withValues(alpha: 0.75)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (final e in edges) {
        canvas.drawLine(corners[e[0]], corners[e[1]], boxPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StlPainter oldDelegate) => true;
}

// ============================================================================
// 📦 ZIP / MINECRAFT-JAR / 3MF INHALTS-INSPEKTOR (ANDROID)
// ============================================================================
class _ZipEntryInfo {
  final String name;
  final bool isDir;
  final int compression;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;

  const _ZipEntryInfo({
    required this.name,
    required this.isDir,
    required this.compression,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });
}

class _ArchiveInspectorScreen extends StatefulWidget {
  final String fileName;
  final String filePath;
  final Uint8List bytes;

  const _ArchiveInspectorScreen({
    required this.fileName,
    required this.filePath,
    required this.bytes,
  });

  @override
  State<_ArchiveInspectorScreen> createState() =>
      _ArchiveInspectorScreenState();
}

class _ArchiveInspectorScreenState extends State<_ArchiveInspectorScreen> {
  List<_ZipEntryInfo> _entries = [];
  String _searchQuery = '';
  String? _minecraftModInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parseZip();
  }

  void _parseZip() {
    try {
      final bytes = widget.bytes;
      final bd = ByteData.sublistView(bytes);
      int eocd = -1;
      final minOff = math.max(0, bytes.length - 65557);
      for (int i = bytes.length - 22; i >= minOff; i--) {
        if (bd.getUint32(i, Endian.little) == 0x06054b50) {
          eocd = i;
          break;
        }
      }
      if (eocd == -1) {
        setState(() => _error = 'Kein gültiges ZIP/JAR-Verzeichnis gefunden.');
        return;
      }

      final totalEntries = bd.getUint16(eocd + 10, Endian.little);
      final cdOffset = bd.getUint32(eocd + 16, Endian.little);
      final parsed = <_ZipEntryInfo>[];
      int ptr = cdOffset;

      for (int i = 0; i < totalEntries && ptr + 46 <= bytes.length; i++) {
        if (bd.getUint32(ptr, Endian.little) != 0x02014b50) break;
        final comp = bd.getUint16(ptr + 10, Endian.little);
        final compSize = bd.getUint32(ptr + 20, Endian.little);
        final uncompSize = bd.getUint32(ptr + 24, Endian.little);
        final nameLen = bd.getUint16(ptr + 28, Endian.little);
        final extraLen = bd.getUint16(ptr + 30, Endian.little);
        final commentLen = bd.getUint16(ptr + 32, Endian.little);
        final localOff = bd.getUint32(ptr + 42, Endian.little);
        final name = utf8.decode(
          bytes.sublist(ptr + 46, math.min(bytes.length, ptr + 46 + nameLen)),
          allowMalformed: true,
        );
        parsed.add(
          _ZipEntryInfo(
            name: name,
            isDir: name.endsWith('/'),
            compression: comp,
            compressedSize: compSize,
            uncompressedSize: uncompSize,
            localHeaderOffset: localOff,
          ),
        );
        ptr += 46 + nameLen + extraLen + commentLen;
      }

      String? mcInfo;
      final modEntry = parsed
          .where(
            (e) =>
                e.name == 'fabric.mod.json' ||
                e.name == 'pack.mcmeta' ||
                e.name.endsWith('mods.toml'),
          )
          .firstOrNull;
      if (modEntry != null) {
        final txt = _extractText(modEntry);
        if (txt != null) {
          try {
            final map = jsonDecode(txt);
            if (map is Map) {
              final modName =
                  map['name'] ??
                  map['id'] ??
                  (map['pack'] is Map ? map['pack']['description'] : null) ??
                  widget.fileName;
              final ver = map['version'] != null ? 'v${map['version']}' : '';
              final desc = map['description'] ?? '';
              mcInfo = '🎮 Minecraft-Paket: $modName $ver\n$desc'.trim();
            }
          } catch (_) {
            mcInfo =
                '🎮 Minecraft-Metadaten (${modEntry.name}) im Archiv erkannt!';
          }
        }
      }

      setState(() {
        _entries = parsed;
        _minecraftModInfo = mcInfo;
      });
    } catch (e) {
      setState(() => _error = 'Archiv-Fehler: $e');
    }
  }

  String? _extractText(_ZipEntryInfo entry) {
    try {
      final bytes = widget.bytes;
      final bd = ByteData.sublistView(bytes);
      final lh = entry.localHeaderOffset;
      if (lh + 30 > bytes.length ||
          bd.getUint32(lh, Endian.little) != 0x04034b50) {
        return null;
      }
      final nameLen = bd.getUint16(lh + 26, Endian.little);
      final extraLen = bd.getUint16(lh + 28, Endian.little);
      final start = lh + 30 + nameLen + extraLen;
      final end = math.min(bytes.length, start + entry.compressedSize);
      final slice = bytes.sublist(start, end);
      if (entry.compression == 0) {
        return utf8.decode(slice, allowMalformed: true);
      } else if (entry.compression == 8) {
        final decompressed = ZLibCodec(raw: true).decode(slice);
        return utf8.decode(decompressed, allowMalformed: true);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase();
    final filtered = _entries
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
        .toList();
    final totalKb =
        _entries.fold<int>(0, (s, e) => s + e.uncompressedSize) / 1024.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName, style: const TextStyle(fontSize: 15)),
            Text(
              '${_entries.length} Einträge • ${totalKb.toStringAsFixed(1)} KB entpackt',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Archiv teilen / speichern',
            onPressed: () {
              Share.shareXFiles([
                XFile(widget.filePath),
              ], text: widget.fileName);
            },
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                if (_minecraftModInfo != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      _minecraftModInfo!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Dateien im Archiv filtern...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final e = filtered[idx];
                      final isText =
                          !e.isDir &&
                          RegExp(
                            r'\.(json|toml|mcmeta|txt|md|cfg|properties|yml|yaml|xml|scad)$',
                            caseSensitive: false,
                          ).hasMatch(e.name);
                      final sizeLabel = e.isDir
                          ? 'Ordner'
                          : (e.uncompressedSize < 1024
                                ? '${e.uncompressedSize} B'
                                : '${(e.uncompressedSize / 1024).toStringAsFixed(1)} KB');
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          e.isDir
                              ? Icons.folder_outlined
                              : (isText
                                    ? Icons.description_outlined
                                    : Icons.insert_drive_file_outlined),
                          color: e.isDir ? Colors.amber.shade700 : Colors.teal,
                        ),
                        title: Text(
                          e.name,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(
                          sizeLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isText
                            ? TextButton(
                                onPressed: () {
                                  final txt = _extractText(e);
                                  showDialog(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: Text(
                                        e.name,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      content: SingleChildScrollView(
                                        child: SelectableText(
                                          txt ?? 'Binärdatei',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx),
                                          child: const Text('Schließen'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Lesen'),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// 🧊 PROZEDURALER 3D-MODELL-GENERATOR (.STL) FÜR ANDROID
// ============================================================================
class _StlProceduralGenerator {
  static ({Uint8List bytes, String fileName}) generateBinaryStl(
    String prompt, {
    double scaleFactor = 1.0,
  }) {
    final lower = prompt.toLowerCase();
    final tris = <List<double>>[];

    void addTri(
      double x1,
      double y1,
      double z1,
      double x2,
      double y2,
      double z2,
      double x3,
      double y3,
      double z3,
    ) {
      tris.add([
        x1 * scaleFactor,
        y1 * scaleFactor,
        z1 * scaleFactor,
        x2 * scaleFactor,
        y2 * scaleFactor,
        z2 * scaleFactor,
        x3 * scaleFactor,
        y3 * scaleFactor,
        z3 * scaleFactor,
      ]);
    }

    void addBox(
      double cx,
      double cy,
      double cz,
      double dx,
      double dy,
      double dz,
    ) {
      final hx = dx / 2, hy = dy / 2, hz = dz / 2;
      final x0 = cx - hx, x1 = cx + hx;
      final y0 = cy - hy, y1 = cy + hy;
      final z0 = cz - hz, z1 = cz + hz;
      final v = [
        [x0, y0, z0],
        [x1, y0, z0],
        [x1, y1, z0],
        [x0, y1, z0],
        [x0, y0, z1],
        [x1, y0, z1],
        [x1, y1, z1],
        [x0, y1, z1],
      ];
      const faces = [
        [0, 2, 1],
        [0, 3, 2],
        [4, 5, 6],
        [4, 6, 7],
        [0, 1, 5],
        [0, 5, 4],
        [2, 3, 7],
        [2, 7, 6],
        [1, 2, 6],
        [1, 6, 5],
        [3, 0, 4],
        [3, 4, 7],
      ];
      for (final f in faces) {
        addTri(
          v[f[0]][0],
          v[f[0]][1],
          v[f[0]][2],
          v[f[1]][0],
          v[f[1]][1],
          v[f[1]][2],
          v[f[2]][0],
          v[f[2]][1],
          v[f[2]][2],
        );
      }
    }

    void addCylinder(
      double cx,
      double cy,
      double z0,
      double z1,
      double rBottom,
      double rTop, {
      int segs = 28,
    }) {
      for (int i = 0; i < segs; i++) {
        final a0 = (i / segs) * 2 * math.pi;
        final a1 = ((i + 1) / segs) * 2 * math.pi;
        final c0 = math.cos(a0), s0 = math.sin(a0);
        final c1 = math.cos(a1), s1 = math.sin(a1);
        final bx0 = cx + rBottom * c0, by0 = cy + rBottom * s0;
        final bx1 = cx + rBottom * c1, by1 = cy + rBottom * s1;
        final tx0 = cx + rTop * c0, ty0 = cy + rTop * s0;
        final tx1 = cx + rTop * c1, ty1 = cy + rTop * s1;
        addTri(bx0, by0, z0, bx1, by1, z0, tx1, ty1, z1);
        addTri(bx0, by0, z0, tx1, ty1, z1, tx0, ty0, z1);
        if (rBottom > 0) addTri(cx, cy, z0, bx1, by1, z0, bx0, by0, z0);
        if (rTop > 0) addTri(cx, cy, z1, tx0, ty0, z1, tx1, ty1, z1);
      }
    }

    if (lower.contains('schnauzer') || lower.contains('hund')) {
      addCylinder(0, 0, 0, 3, 28, 30, segs: 36);
      addBox(0, -2, 11, 18, 30, 14);
      addBox(0, 7, 14, 20, 14, 15);
      addBox(-6, 18, 5, 5, 14, 4);
      addBox(6, 18, 5, 5, 14, 4);
      addBox(-8, -12, 6, 6, 12, 6);
      addBox(8, -12, 6, 6, 12, 6);
      addBox(0, 12, 22, 11, 10, 12);
      addBox(0, 16, 29, 13, 13, 11);
      addBox(0, 25, 27, 9, 10, 7);
      addBox(0, 26, 22, 10, 9, 9);
      addBox(-4, 21, 34, 4, 4, 2);
      addBox(4, 21, 34, 4, 4, 2);
      addBox(-6, 15, 34, 3, 5, 6);
      addBox(6, 15, 34, 3, 5, 6);
      addBox(0, -18, 19, 3.5, 4, 9);
    } else if (lower.contains('zahnrad') || lower.contains('gear')) {
      final teeth = 20;
      addCylinder(0, 0, 0, 8, 22, 22, segs: 40);
      for (int i = 0; i < teeth; i++) {
        final a = (i / teeth) * 2 * math.pi;
        addBox(24 * math.cos(a), 24 * math.sin(a), 4, 5, 5, 8);
      }
    } else if (lower.contains('rakete') || lower.contains('rocket')) {
      addCylinder(0, 0, 0, 6, 12, 9, segs: 28);
      addCylinder(0, 0, 6, 42, 10, 10, segs: 28);
      addCylinder(0, 0, 42, 62, 10, 0.2, segs: 28);
      addBox(-12, 0, 10, 8, 2.5, 16);
      addBox(12, 0, 10, 8, 2.5, 16);
      addBox(0, -12, 10, 2.5, 8, 16);
      addBox(0, 12, 10, 2.5, 8, 16);
    } else if (lower.contains('burg') || lower.contains('castle')) {
      addBox(0, 0, 1.5, 56, 56, 3);
      addBox(0, 18, 10, 38, 4, 16);
      addBox(0, -18, 10, 38, 4, 16);
      addBox(-18, 0, 10, 4, 38, 16);
      addBox(18, 0, 10, 4, 38, 16);
      for (final sx in [-18.0, 18.0]) {
        for (final sy in [-18.0, 18.0]) {
          addCylinder(sx, sy, 2, 26, 6.5, 6.5, segs: 20);
          addCylinder(sx, sy, 26, 36, 7.5, 0.2, segs: 20);
        }
      }
      addBox(0, 0, 15, 16, 16, 26);
    } else if (lower.contains('anhänger') || lower.contains('schild')) {
      addBox(0, 0, 2, 54, 22, 4);
      addCylinder(-22, 0, 0, 4, 4, 4, segs: 20);
      addBox(4, 0, 5, 34, 10, 2.5);
    } else {
      addCylinder(0, 0, 0, 4, 24, 26, segs: 32);
      addCylinder(0, 0, 4, 28, 18, 12, segs: 6);
      addCylinder(0, 0, 28, 42, 12, 0.2, segs: 6);
    }

    final byteLen = 84 + tris.length * 50;
    final out = Uint8List(byteLen);
    final bd = ByteData.sublistView(out);
    final header = 'ChatConnect 3D STL Generator - $prompt'
        .padRight(80)
        .substring(0, 80);
    for (int i = 0; i < 80; i++) {
      out[i] = header.codeUnitAt(i) & 0x7F;
    }
    bd.setUint32(80, tris.length, Endian.little);

    int off = 84;
    for (final t in tris) {
      final ux = t[3] - t[0], uy = t[4] - t[1], uz = t[5] - t[2];
      final vx = t[6] - t[0], vy = t[7] - t[1], vz = t[8] - t[2];
      double nx = uy * vz - uz * vy;
      double ny = uz * vx - ux * vz;
      double nz = ux * vy - uy * vx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 0) {
        nx /= len;
        ny /= len;
        nz /= len;
      }
      bd.setFloat32(off, nx, Endian.little);
      bd.setFloat32(off + 4, ny, Endian.little);
      bd.setFloat32(off + 8, nz, Endian.little);
      for (int k = 0; k < 9; k++) {
        bd.setFloat32(off + 12 + k * 4, t[k], Endian.little);
      }
      bd.setUint16(off + 48, 0, Endian.little);
      off += 50;
    }

    final slug = prompt
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fileName = '${slug.isEmpty ? "modell_3d" : slug}.stl';
    return (bytes: out, fileName: fileName);
  }
}
