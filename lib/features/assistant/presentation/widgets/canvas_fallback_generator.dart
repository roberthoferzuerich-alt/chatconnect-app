import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CanvasFallbackGenerator {
  /// Generiert ein stilvolles, procedurals Bild als Offline-/Canvas-Fallback
  static Future<Uint8List> generateArtisticFallback({
    required String prompt,
    required String styleLabel,
    required String modelLabel,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final w = width.toDouble();
    final h = height.toDouble();

    // 1. Edler ChatConnect Hintergrundverlauf (Smaragd-Türkis #00a884 & Cyan-Blau)
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(w, h),
        [
          const Color(0xFF031613),
          const Color(0xFF00382B),
          const Color(0xFF04293A),
          const Color(0xFF021018),
        ],
        [0.0, 0.4, 0.75, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Leuchtende KI-Wellen und Glaskugel-Atmosphäre
    final random = math.Random(prompt.hashCode);

    // Sanfte Radial-Glows
    for (int i = 0; i < 4; i++) {
      final cx = random.nextDouble() * w;
      final cy = random.nextDouble() * h;
      final radius = (0.2 + random.nextDouble() * 0.4) * math.min(w, h);
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          radius,
          [
            (i % 2 == 0 ? const Color(0xFF00A884) : const Color(0xFF00E5FF)).withOpacity(0.22),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(Offset(cx, cy), radius, glowPaint);
    }

    // Stil-spezifische Grafikelemente
    if (styleLabel.contains('Minecraft') || styleLabel.contains('Voxel')) {
      _drawVoxelElements(canvas, w, h, random);
    } else if (styleLabel.contains('Cyberpunk')) {
      _drawCyberpunkGrid(canvas, w, h, random);
    } else {
      _drawSmoothGlowingWaves(canvas, w, h, random);
    }

    // 3D-Glaskugeln / Orbs
    _drawGlassSpheres(canvas, w, h, random);

    // 3. Typografie & Prompt-Overlay im Kartenstil
    _drawPromptCardOverlay(canvas, w, h, prompt, styleLabel, modelLabel);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawSmoothGlowingWaves(Canvas canvas, double w, double h, math.Random random) {
    for (int wave = 0; wave < 6; wave++) {
      final path = Path();
      final startY = h * (0.3 + wave * 0.08);
      path.moveTo(0, startY);

      final cp1x = w * 0.25;
      final cp1y = startY - 80 + math.sin(wave) * 60;
      final cp2x = w * 0.65;
      final cp2y = startY + 80 + math.cos(wave) * 70;
      final endX = w;
      final endY = startY + (random.nextDouble() - 0.5) * 60;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, endX, endY);

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + wave * 0.8
        ..shader = ui.Gradient.linear(
          Offset(0, startY),
          Offset(w, endY),
          [
            const Color(0xFF00E5FF).withOpacity(0.15),
            const Color(0xFF00A884).withOpacity(0.65),
            const Color(0xFF25D366).withOpacity(0.4),
          ],
        );
      canvas.drawPath(path, wavePaint);
    }
  }

  static void _drawCyberpunkGrid(Canvas canvas, double w, double h, math.Random random) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.2)
      ..strokeWidth = 1.5;

    final horizon = h * 0.6;
    for (double x = 0; x <= w; x += w / 12) {
      canvas.drawLine(Offset(x, horizon), Offset((x - w / 2) * 2.5 + w / 2, h), gridPaint);
    }
    for (double y = horizon; y <= h; y += (h - horizon) / 8) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  static void _drawVoxelElements(Canvas canvas, double w, double h, math.Random random) {
    final voxelPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 24; i++) {
      final size = 20.0 + random.nextDouble() * 40;
      final x = random.nextDouble() * (w - size);
      final y = random.nextDouble() * (h * 0.65);
      final isDiamond = random.nextBool();

      voxelPaint.color = (isDiamond ? const Color(0xFF00E5FF) : const Color(0xFF00A884))
          .withOpacity(0.35 + random.nextDouble() * 0.3);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, size, size), const Radius.circular(4)),
        voxelPaint,
      );
    }
  }

  static void _drawGlassSpheres(Canvas canvas, double w, double h, math.Random random) {
    for (int i = 0; i < 9; i++) {
      final radius = 25.0 + random.nextDouble() * 45;
      final cx = (0.1 + 0.8 * random.nextDouble()) * w;
      final cy = (0.2 + 0.5 * random.nextDouble()) * h;

      // Kugel-Schatten
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx + 6, cy + 8), radius, shadowPaint);

      // Kugel-Körper (Glaseffekt)
      final spherePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - radius * 0.35, cy - radius * 0.35),
          radius * 1.3,
          [
            Colors.white.withOpacity(0.85),
            const Color(0xFF00E5FF).withOpacity(0.45),
            const Color(0xFF00A884).withOpacity(0.3),
            Colors.black.withOpacity(0.2),
          ],
          [0.0, 0.35, 0.75, 1.0],
        );
      canvas.drawCircle(Offset(cx, cy), radius, spherePaint);

      // Kugel-Lichtkante (Randglanz)
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.linear(
          Offset(cx - radius, cy - radius),
          Offset(cx + radius, cy + radius),
          [Colors.white.withOpacity(0.9), const Color(0xFF00A884).withOpacity(0.4)],
        );
      canvas.drawCircle(Offset(cx, cy), radius, rimPaint);

      // Leuchtender Glanzpunkt
      final specPaint = Paint()..color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(Offset(cx - radius * 0.38, cy - radius * 0.38), radius * 0.18, specPaint);
    }
  }

  static void _drawPromptCardOverlay(
    Canvas canvas,
    double w,
    double h,
    String prompt,
    String styleLabel,
    String modelLabel,
  ) {
    // Untere Glass-Plakette
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.68, w * 0.88, h * 0.26),
      const Radius.circular(20),
    );

    // Schatten
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(cardRect, shadowPaint);

    // Milchglas Card Fill
    final cardFill = Paint()..color = const Color(0xFF021714).withOpacity(0.82);
    canvas.drawRRect(cardRect, cardFill);

    // Rand
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(
        Offset(cardRect.left, cardRect.top),
        Offset(cardRect.right, cardRect.bottom),
        [const Color(0xFF00A884), const Color(0xFF00E5FF).withOpacity(0.4)],
      );
    canvas.drawRRect(cardRect, borderPaint);

    // Text: Titel / Badge
    final badgePainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '✨ ChatConnect KI-Studio  •  ',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          TextSpan(
            text: '$modelLabel ($styleLabel)',
            style: const TextStyle(
              color: Color(0xFF00A884),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cardRect.width - 40);
    badgePainter.paint(canvas, Offset(cardRect.left + 24, cardRect.top + 20));

    // Text: Prompt
    final promptPainter = TextPainter(
      text: TextSpan(
        text: '„$prompt“',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: cardRect.width - 48);
    promptPainter.paint(canvas, Offset(cardRect.left + 24, cardRect.top + 52));
  }
}
