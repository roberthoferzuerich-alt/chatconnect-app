import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../presentation/widgets/canvas_fallback_generator.dart';

enum AiModelOption {
  fluxPro('Flux Pro', 'flux', 'Höchste Qualität & Detailtreue', Icons.auto_awesome),
  fluxRealism('Flux Realism', 'flux-realism', 'Lebensechter Fotorealismus', Icons.camera_enhance),
  turboSpeed('Turbo Speed', 'turbo', 'Ultraschnell in wenigen Sekunden', Icons.bolt),
  threeDGaming('3D & Gaming', 'flux', '3D Render & Gaming-Grafik', Icons.view_in_ar);

  final String label;
  final String apiModel;
  final String description;
  final IconData icon;

  const AiModelOption(this.label, this.apiModel, this.description, this.icon);
}

enum AiStyleOption {
  auto('Auto', ''),
  photo('Fotorealistisch', ', ultra realistic photography, 8k uhd, photorealistic, cinematic lighting, sharp focus, 35mm lens'),
  threeD('3D-Render', ', 3d render, octane render, ray tracing, unreal engine 5, smooth textures, studio lighting, highly detailed'),
  minecraft('Minecraft / Voxel', ', voxel art, isometric voxel style, minecraft aesthetic, cubic 3d blocks, clean vibrant lighting'),
  anime('Anime / Comic', ', modern vibrant anime art style, studio ghibli inspired, expressive, clean lineart, digital illustration'),
  cyberpunk('Cyberpunk', ', cyberpunk style, neon emerald #00a884 and cyan glow, futuristic city, reflections on wet asphalt, cinematic'),
  oilPainting('Ölgemälde / Kunst', ', classical oil painting, textured canvas brush strokes, artistic masterpiece, impasto style, museum lighting');

  final String label;
  final String promptSuffix;

  const AiStyleOption(this.label, this.promptSuffix);
}

enum AiAspectRatioOption {
  square('Quadratisch (1:1)', 1024, 1024, Icons.crop_square),
  landscape('Querformat (16:9)', 1280, 720, Icons.crop_16_9),
  portrait('Hochformat (9:16)', 720, 1280, Icons.crop_portrait);

  final String label;
  final int baseWidth;
  final int baseHeight;
  final IconData icon;

  const AiAspectRatioOption(this.label, this.baseWidth, this.baseHeight, this.icon);
}

enum AiResolutionOption {
  oneK('1K', 1.0, '1024px'),
  hd('HD', 1.25, '1280px'),
  twoK('2K', 1.6, '2048px');

  final String label;
  final double scale;
  final String description;

  const AiResolutionOption(this.label, this.scale, this.description);
}

class AiImageResult {
  final Uint8List bytes;
  final File file;
  final bool isFallback;
  final String prompt;
  final AiModelOption model;
  final AiStyleOption style;
  final int width;
  final int height;

  AiImageResult({
    required this.bytes,
    required this.file,
    required this.isFallback,
    required this.prompt,
    required this.model,
    required this.style,
    required this.width,
    required this.height,
  });
}

final aiImageServiceProvider = Provider<AiImageService>((ref) {
  return AiImageService();
});

class AiImageService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 25),
    ),
  );

  /// Generiert ein Bild über die kostenlose Schnittstelle (Pollinations) oder den lokalen Canvas-Fallback
  Future<AiImageResult> generateImage({
    required String prompt,
    required AiModelOption model,
    required AiStyleOption style,
    required AiAspectRatioOption format,
    required AiResolutionOption resolution,
    Uint8List? seedImageBytes,
  }) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      throw Exception('Bitte gib eine Bildbeschreibung ein.');
    }

    final targetWidth = (format.baseWidth * resolution.scale).round();
    final targetHeight = (format.baseHeight * resolution.scale).round();

    // Prompt verfeinern
    String enhancedPrompt = cleanPrompt;
    if (style.promptSuffix.isNotEmpty) {
      enhancedPrompt += style.promptSuffix;
    }
    if (model == AiModelOption.threeDGaming && style != AiStyleOption.threeD) {
      enhancedPrompt += ', 3d game asset, octane render, stylized 3d';
    }

    final seed = math.Random().nextInt(9999999);
    final encodedPrompt = Uri.encodeComponent(enhancedPrompt);
    final url =
        'https://image.pollinations.ai/prompt/$encodedPrompt?width=$targetWidth&height=$targetHeight&model=${model.apiModel}&nologo=true&seed=$seed';

    Uint8List? resultBytes;
    bool isFallback = false;

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        resultBytes = Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('KI API fehlgeschlagen oder offline ($e). Starte lokalen Canvas-Fallback...');
    }

    // Wenn API fehlschlug oder offline ist: Lokaler Canvas-Fallback
    if (resultBytes == null || resultBytes.isEmpty) {
      isFallback = true;
      resultBytes = await CanvasFallbackGenerator.generateArtisticFallback(
        prompt: cleanPrompt,
        styleLabel: style.label,
        modelLabel: model.label,
        width: targetWidth,
        height: targetHeight,
      );
    }

    // Temporäre Datei anlegen für direkte Weiterleitung in Chats / Wallpaper
    final tempDir = await getTemporaryDirectory();
    final fileName = 'chatconnect_ai_${DateTime.now().millisecondsSinceEpoch}.png';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(resultBytes);

    return AiImageResult(
      bytes: resultBytes,
      file: tempFile,
      isFallback: isFallback,
      prompt: cleanPrompt,
      model: model,
      style: style,
      width: targetWidth,
      height: targetHeight,
    );
  }

  /// Speichert Bild in die Galerie des Nutzers
  Future<bool> saveToGallery(String filePath) async {
    try {
      await Gal.putImage(filePath);
      return true;
    } catch (e) {
      debugPrint('Fehler beim Speichern in Galerie: $e');
      return false;
    }
  }
}
