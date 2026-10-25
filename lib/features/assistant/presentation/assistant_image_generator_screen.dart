import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../settings/presentation/chats_settings_provider.dart';
import '../data/ai_image_service.dart';
import 'widgets/chat_recipient_dialog.dart';

class AssistantImageGeneratorScreen extends ConsumerStatefulWidget {
  final int? targetConversationId;

  const AssistantImageGeneratorScreen({
    super.key,
    this.targetConversationId,
  });

  @override
  ConsumerState<AssistantImageGeneratorScreen> createState() =>
      _AssistantImageGeneratorScreenState();
}

class _AssistantImageGeneratorScreenState
    extends ConsumerState<AssistantImageGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();

  AiModelOption _selectedModel = AiModelOption.fluxPro;
  AiStyleOption _selectedStyle = AiStyleOption.auto;
  AiAspectRatioOption _selectedFormat = AiAspectRatioOption.square;
  AiResolutionOption _selectedResolution = AiResolutionOption.oneK;

  bool _isGenerating = false;
  String? _statusMessage;
  File? _currentImageFile;
  Uint8List? _currentImageBytes;
  bool _isAiGenerated = false;

  late AnimationController _animController;

  final List<String> _promptSuggestions = [
    'Ein Mittelschnauzer als Jedi-Ritter mit grünem Lichtschwert',
    'Minecraft Diamant-Schwert im Neon-Stil',
    'Futuristische Cyberpunk-Stadt bei Nacht mit Spiegelungen',
    'Smaragd-Kristall-Drache im Zauberwald mit Glühwürmchen',
    '3D-Glaskugeln mit leuchtenden KI-Wellen im Weltall',
    'Klassisches Ölgemälde einer verträumten Küstenstadt bei Sonnenuntergang',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib zuerst eine Bildbeschreibung (Prompt) ein.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _statusMessage = 'KI erschafft dein Bild...';
    });

    try {
      final service = ref.read(aiImageServiceProvider);
      final result = await service.generateImage(
        prompt: prompt,
        model: _selectedModel,
        style: _selectedStyle,
        format: _selectedFormat,
        resolution: _selectedResolution,
      );

      setState(() {
        _currentImageFile = result.file;
        _currentImageBytes = result.bytes;
        _isAiGenerated = true;
        _isGenerating = false;
      });

      if (mounted) {
        if (result.isFallback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✨ Offline/Canvas-Modus: Dein Bild wurde lokal im ChatConnect-Design generiert!',
              ),
              backgroundColor: Color(0xFF00A884),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Dein KI-Bild wurde erfolgreich generiert!'),
              backgroundColor: Color(0xFF00A884),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Generierung: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImageSource() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Bildquelle wählen',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F8F5),
                  child: Icon(Icons.photo_library, color: Color(0xFF00A884)),
                ),
                title: const Text('Fotogalerie'),
                subtitle: const Text('Bild aus deiner Handy-/PC-Galerie wählen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F7FA),
                  child: Icon(Icons.folder_open, color: Color(0xFF00ACC1)),
                ),
                title: const Text('Datei auswählen'),
                subtitle: const Text('PNG, JPG, WebP vom Speicher laden'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFile();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7F6),
                  child: Icon(Icons.camera_alt, color: Color(0xFF7E57C2)),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Neues Foto aufnehmen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final file = File(picked.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _currentImageFile = file;
          _currentImageBytes = bytes;
          _isAiGenerated = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler bei Bildauswahl: $e');
    }
  }

  Future<void> _pickFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _currentImageFile = file;
          _currentImageBytes = bytes;
          _isAiGenerated = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Dateiladen: $e');
    }
  }

  Future<void> _cropCurrentImage() async {
    if (_currentImageFile == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentImageFile!.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Bild zuschneiden',
            toolbarColor: const Color(0xFF00A884),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Bild zuschneiden',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );

      if (cropped != null) {
        final croppedFile = File(cropped.path);
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _currentImageFile = croppedFile;
          _currentImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Zuschneiden auf dieser Plattform nicht unterstützt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zuschneide-Tool auf diesem Gerät nicht verfügbar.'),
          ),
        );
      }
    }
  }

  Future<void> _saveAsWallpaper() async {
    if (_currentImageFile == null) return;
    try {
      await ref
          .read(chatsSettingsProvider.notifier)
          .setWallpaper(_currentImageFile!.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00A884),
            content: Text('🖼️ Als Chat-Hintergrundbild übernommen!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Setzen des Hintergrunds: $e')),
        );
      }
    }
  }

  Future<void> _downloadImage() async {
    if (_currentImageFile == null) return;
    try {
      final service = ref.read(aiImageServiceProvider);
      final success = await service.saveToGallery(_currentImageFile!.path);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF00A884),
              content: Text('💾 Bild erfolgreich in der Galerie gespeichert!'),
            ),
          );
        } else {
          // Fallback share / info
          await Share.shareXFiles(
            [XFile(_currentImageFile!.path)],
            text: 'Mein generiertes Bild von ChatConnect AI',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  void _openChatSendDialog() {
    if (_currentImageFile == null) return;
    showDialog(
      context: context,
      builder: (ctx) => ChatRecipientDialog(
        imageFile: _currentImageFile!,
        defaultCaption: _promptController.text.isNotEmpty
            ? _promptController.text.trim()
            : null,
      ),
    );
  }

  void _showFullscreenPreview() {
    if (_currentImageBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_currentImageBytes!),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.65),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromptInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF00A884)),
            SizedBox(width: 8),
            Text('Tipps für tolle Prompts', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Der ChatConnect-Assistent versteht Deutsch, Englisch und viele weitere Sprachen.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tipps für beste Ergebnisse:\n'
              '• Beschreibe das Hauptmotiv präzise\n'
              '• Nenne Details wie Lichtstimmung, Farben & Umgebung\n'
              '• Wähle unten den passenden Style & Auflösung\n'
              '• Keine API-Kosten & unbegrenzt nutzbar!',
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              'Beispiele zum Ausprobieren:\n'
              '• „Ein Mittelschnauzer als Jedi-Ritter mit grünem Lichtschwert“\n'
              '• „Minecraft Diamant-Schwert im Neon-Stil“\n'
              '• „Cyberpunk-Metropole mit Hologrammen bei Nacht“',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF00A884),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Verstanden', style: TextStyle(color: Color(0xFF00A884))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 850;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00A884).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'ChatConnect AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: _showPromptInfo,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Edler ChatConnect-Assistenten-Hintergrund (Smaragd-Türkis & Cyan-Blau & 3D-Kugeln)
          _buildBackground(size),

          // 2. Inhalt
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // Header Bereich (Badge, Titel, Untertitel wie bei Pixella)
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // Die beiden weißen Karten (Left: Upload/Preview, Right: Prompt & Options)
                      if (isWide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: _buildLeftCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 7, child: _buildRightCard()),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _buildLeftCard(),
                            const SizedBox(height: 20),
                            _buildRightCard(),
                          ],
                        ),

                      // Direkt-Aktionen für ChatConnect
                      if (_currentImageFile != null) ...[
                        const SizedBox(height: 24),
                        _buildDirectActionsBar(),
                      ],
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hintergrund mit dem generierten Smaragd-Türkis Bild + animierten sanften Glaskugeln
  Widget _buildBackground(Size size) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Bild-Asset
          Image.asset(
            'assets/img/chatconnect_assistant_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF031915),
                    Color(0xFF00382E),
                    Color(0xFF042738),
                    Color(0xFF02131D),
                  ],
                ),
              ),
            ),
          ),

          // Sanfter Abdunkelungs- und Leucht-Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.3, 0.75, 1.0],
              ),
            ),
          ),

          // Subtile animierte Glaskugeln / Schwebende Partikel
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _FloatingGlassOrbsPainter(progress: _animController.value),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Header Bereich nach Vorbild des Screenshots
  Widget _buildHeader() {
    return Column(
      children: [
        // Grüner Badge "✓ 100 % automatisch"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF25D366), size: 16),
              SizedBox(width: 6),
              Text(
                '100 % automatisch  •  Ohne API-Kosten',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Großer Titel "KI-Bildgenerator"
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE0F2F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            'KI-Bildgenerator',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: [
                Shadow(color: Color(0xFF00A884), blurRadius: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Subtiler Untertitel
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Erschaffe faszinierende KI-Bilder für deine Chats, erstelle Wallpaper oder veredle eigene Fotos mit dem ChatConnect-Assistenten – blitzschnell & unbegrenzt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  /// Linke Karte: Bild hochladen oder Vorschau des generierten Bildes
  Widget _buildLeftCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header der linken Karte
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _currentImageFile != null ? Icons.image_rounded : Icons.cloud_upload_outlined,
                    color: const Color(0xFF00A884),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentImageFile != null
                        ? (_isAiGenerated ? 'KI-Vorschau' : 'Vorlage / Foto')
                        : 'Bild hochladen',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF111B21),
                    ),
                  ),
                ],
              ),
              if (_currentImageFile != null)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Color(0xFF00A884)),
                      tooltip: 'Vollbild',
                      onPressed: _showFullscreenPreview,
                    ),
                    IconButton(
                      icon: const Icon(Icons.crop, color: Colors.grey),
                      tooltip: 'Zuschneiden',
                      onPressed: _cropCurrentImage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Entfernen',
                      onPressed: () {
                        setState(() {
                          _currentImageFile = null;
                          _currentImageBytes = null;
                          _isAiGenerated = false;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Content Bereich: Entweder Bildvorschau oder gestrichelter Upload-Bereich
          Expanded(
            child: _currentImageBytes != null
                ? _buildImagePreview()
                : _buildEmptyUploadArea(),
          ),
        ],
      ),
    );
  }

  /// Gestrichelter Upload Bereich nach Pixella-Vorbild
  Widget _buildEmptyUploadArea() {
    return InkWell(
      onTap: _pickImageSource,
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: Colors.grey.shade300,
          strokeWidth: 1.6,
          radius: 18,
          dashWidth: 6,
          dashSpace: 4,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Grüner Pill-Button "☁️ Bild hochladen" wie im Bild
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00A884), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A884).withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: Color(0xFF00A884), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Bild hochladen',
                      style: TextStyle(
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Untertitel "oder hier ablegen"
              Text(
                'oder hier ablegen',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Vorlagen laden, zuschneiden oder veredeln',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bild-Vorschau
  Widget _buildImagePreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _currentImageBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAiGenerated ? Icons.auto_awesome : Icons.check_circle,
                  color: const Color(0xFF00E5FF),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _isAiGenerated ? 'KI-Meisterwerk' : 'Vorlage bereit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Rechte Karte: Prompt-Eingabe & Auswahl-Leiste unten
  Widget _buildRightCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Großes Textfeld mit Info-Icon rechts oben
          Stack(
            children: [
              TextField(
                controller: _promptController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Beschreibe in einer beliebigen Sprache, welches Bild du erstellen möchtest …',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 36, bottom: 8),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF111B21),
                  height: 1.4,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(Icons.info_outline, size: 20, color: Colors.grey.shade400),
                  tooltip: 'Tipps & Beispiele',
                  onPressed: _showPromptInfo,
                ),
              ),
            ],
          ),

          // Schnelle Prompt-Vorschläge (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _promptSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                  child: ActionChip(
                    backgroundColor: const Color(0xFFF0F4F4),
                    side: BorderSide(color: Colors.grey.shade200),
                    label: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF00382E)),
                    ),
                    onPressed: () {
                      _promptController.text = suggestion;
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Spacer(),

          // Untere Auswahl-Leiste genau wie im Bild
          _buildPixellaBottomControlBar(),
        ],
      ),
    );
  }

  /// Untere Auswahl-Leiste nach dem exakten Pixella-Layout
  Widget _buildPixellaBottomControlBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildModelDropdown(),
                    _buildStyleDropdown(),
                    _buildFormatDropdown(),
                    _buildResolutionDropdown(),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGenerateButton(),
              ],
            );
          }

          return Row(
            children: [
              _buildModelDropdown(),
              const SizedBox(width: 6),
              _buildStyleDropdown(),
              const SizedBox(width: 6),
              _buildFormatDropdown(),
              const SizedBox(width: 6),
              _buildResolutionDropdown(),
              const Spacer(),
              _buildGenerateButton(),
            ],
          );
        },
      ),
    );
  }

  /// KI-Modell Dropdown (z. B. Flux Pro, Realism, Turbo, 3D & Gaming)
  Widget _buildModelDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AiModelOption>(
          value: _selectedModel,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          onChanged: (val) {
            if (val != null) setState(() => _selectedModel = val);
          },
          items: AiModelOption.values.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(model.icon, size: 16, color: const Color(0xFF00A884)),
                  const SizedBox(width: 6),
                  Text(
                    model.label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Style Dropdown (Auto, Fotorealistisch, 3D-Render, Minecraft, etc.)
  Widget _buildStyleDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AiStyleOption>(
          value: _selectedStyle,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          onChanged: (val) {
            if (val != null) setState(() => _selectedStyle = val);
          },
          items: AiStyleOption.values.map((style) {
            return DropdownMenuItem(
              value: style,
              child: Text(
                style == AiStyleOption.auto ? 'Style: Auto' : style.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Format Dropdown (1:1, 16:9, 9:16)
  Widget _buildFormatDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AiAspectRatioOption>(
          value: _selectedFormat,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          onChanged: (val) {
            if (val != null) setState(() => _selectedFormat = val);
          },
          items: AiAspectRatioOption.values.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(format.icon, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(
                    format == AiAspectRatioOption.square
                        ? '1:1'
                        : (format == AiAspectRatioOption.landscape ? '16:9' : '9:16'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Auflösung Dropdown (1K, HD, 2K)
  Widget _buildResolutionDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AiResolutionOption>(
          value: _selectedResolution,
          icon: const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
          onChanged: (val) {
            if (val != null) setState(() => _selectedResolution = val);
          },
          items: AiResolutionOption.values.map((res) {
            return DropdownMenuItem(
              value: res,
              child: Text(
                res.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Grüner Button rechts: "✨ Bild generieren"
  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
      ),
      onPressed: _isGenerating ? null : _generateImage,
      icon: _isGenerating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text(
        _isGenerating ? (_statusMessage ?? 'Generiere...') : 'Bild generieren',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Direkt-Aktionen für ChatConnect
  Widget _buildDirectActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // 📤 Direkt in den Chat senden
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'Direkt in Chat senden',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _openChatSendDialog,
          ),

          // 🖼️ Als Chat-Hintergrundbild übernehmen
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00382E),
              side: const BorderSide(color: Color(0xFF00A884), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.wallpaper, size: 18, color: Color(0xFF00A884)),
            label: const Text(
              'Als Chat-Hintergrund übernehmen',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _saveAsWallpaper,
          ),

          // 💾 Bild als PNG/JPG herunterladen
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF111B21),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.download, size: 18, color: Colors.blueAccent),
            label: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: _downloadImage,
          ),

          // 🔗 Teilen
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF0F2F5),
              foregroundColor: const Color(0xFF111B21),
            ),
            icon: const Icon(Icons.share, size: 18),
            tooltip: 'Teilen',
            onPressed: () {
              if (_currentImageFile != null) {
                Share.shareXFiles(
                  [XFile(_currentImageFile!.path)],
                  text: 'Mit ChatConnect KI erstellt',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Maler für die subtilen leuchtenden 3D-Glaskugeln im ChatConnect-Design
class _FloatingGlassOrbsPainter extends CustomPainter {
  final double progress;

  _FloatingGlassOrbsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final orbs = [
      _OrbData(0.12, 0.25, 38, const Color(0xFF00A884)),
      _OrbData(0.85, 0.20, 48, const Color(0xFF00E5FF)),
      _OrbData(0.78, 0.65, 32, const Color(0xFF00A884)),
      _OrbData(0.18, 0.72, 42, const Color(0xFF00E5FF)),
      _OrbData(0.50, 0.12, 24, Colors.white),
    ];

    for (int i = 0; i < orbs.length; i++) {
      final orb = orbs[i];
      final floatOffset = math.sin((progress * 2 * math.pi) + (i * 1.5)) * 14;
      final cx = orb.relX * w;
      final cy = orb.relY * h + floatOffset;

      // Glow
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orb.radius * 2));
      canvas.drawCircle(Offset(cx, cy), orb.radius * 2, glowPaint);

      // Kugel-Körper
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [
            Colors.white.withOpacity(0.6),
            orb.color.withOpacity(0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orb.radius));
      canvas.drawCircle(Offset(cx, cy), orb.radius, bodyPaint);

      // Glanzpunkt
      final specPaint = Paint()..color = Colors.white.withOpacity(0.75);
      canvas.drawCircle(
        Offset(cx - orb.radius * 0.35, cy - orb.radius * 0.35),
        orb.radius * 0.2,
        specPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingGlassOrbsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OrbData {
  final double relX;
  final double relY;
  final double radius;
  final Color color;

  const _OrbData(this.relX, this.relY, this.radius, this.color);
}

/// Maler für den gestrichelten Rand im Upload-Kärtchen
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final dashedPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        dest.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
