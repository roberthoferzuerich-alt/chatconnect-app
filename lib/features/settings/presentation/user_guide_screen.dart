import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/user_guide.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTapLink(String text, String? href, String title) {
    if (href == null || href.isEmpty) return;

    if (href.startsWith('#')) {
      final rawSlug = Uri.decodeComponent(href.substring(1)).toLowerCase();
      final normSlug = rawSlug.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
      final leadNumMatch = RegExp(r'^(\d+)').firstMatch(normSlug);
      final leadNum = leadNumMatch?.group(1);

      final lines = appUserGuideMarkdown.split('\n');
      int targetCharOffset = -1;
      int runningChars = 0;

      for (final line in lines) {
        if (line.startsWith('#')) {
          final headingText = line.replaceFirst(RegExp(r'^#+\s*'), '').trim().toLowerCase();
          final hSlug = headingText
              .replaceAll(RegExp(r'\s+'), '-')
              .replaceAll(RegExp(r'[^a-z0-9äöüß\-]'), '')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');
          final hNumMatch = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(headingText);
          final hNum = hNumMatch?.group(1)?.replaceAll('.', '');

          if (hSlug == normSlug ||
              (normSlug.isNotEmpty && hSlug.startsWith(normSlug)) ||
              (leadNum != null && hNum == leadNum)) {
            targetCharOffset = runningChars;
            break;
          }
        }
        runningChars += line.length + 1;
      }

      if (targetCharOffset >= 0 && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final ratio = (targetCharOffset / appUserGuideMarkdown.length).clamp(0.0, 1.0);
        _scrollController.animateTo(
          maxScroll * ratio,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    Clipboard.setData(ClipboardData(text: href));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link in Zwischenablage kopiert: $href'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzerhandbuch')),
      body: Markdown(
        controller: _scrollController,
        data: appUserGuideMarkdown,
        selectable: true,
        onTapLink: _handleTapLink,
      ),
    );
  }
}
