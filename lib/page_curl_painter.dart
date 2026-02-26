import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'pages.dart';

Future<ui.Image> rasterizePageImage({
  required Size size,
  required DemoPageData page,
  required PageTypography typography,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect pageRect = Offset.zero & size;

  final Paint basePaint = Paint()
    ..shader = ui.Gradient.linear(
      pageRect.topLeft,
      pageRect.bottomRight,
      const [Color(0xFFF8F1E3), Color(0xFFF4EAD8)],
      const [0.0, 1.0],
    );
  canvas.drawRect(pageRect, basePaint);

  final Paint vignettePaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset(size.width * 0.12, size.height * 0.08),
      size.longestSide * 1.1,
      [Colors.white.withOpacity(0.20), Colors.transparent],
      const [0.0, 1.0],
    );
  canvas.drawRect(pageRect, vignettePaint);

  final Paint borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = Colors.black.withOpacity(0.10);
  canvas.drawRect(pageRect.deflate(0.7), borderPaint);

  final double contentWidth = size.width - typography.horizontalPadding * 2;
  final double startX = typography.horizontalPadding;
  double cursorY = typography.topPadding;

  final TextPainter titlePainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 2,
    text: TextSpan(
      text: page.title,
      style: TextStyle(
        fontSize: typography.titleSize,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF27221A),
        letterSpacing: 0.2,
      ),
    ),
  )..layout(maxWidth: contentWidth);
  titlePainter.paint(canvas, Offset(startX, cursorY));
  cursorY += titlePainter.height + typography.paragraphSpacing;

  final List<String> paragraphs = page.body.split('\n\n');
  for (final String paragraph in paragraphs) {
    final TextPainter bodyPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: paragraph,
        style: TextStyle(
          fontSize: typography.bodySize,
          height: typography.lineHeight,
          color: const Color(0xFF3A3328),
          letterSpacing: 0.1,
        ),
      ),
    )..layout(maxWidth: contentWidth);

    bodyPainter.paint(canvas, Offset(startX, cursorY));
    cursorY += bodyPainter.height + typography.paragraphSpacing;
  }

  final TextPainter pageNoPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: '- ${page.pageNumber} -',
      style: TextStyle(
        fontSize: typography.pageNumberSize,
        color: const Color(0xFF6C6454),
        letterSpacing: 1.2,
      ),
    ),
  )..layout(maxWidth: contentWidth);

  final double pageNoY = size.height - typography.bottomPadding;
  pageNoPainter.paint(
    canvas,
    Offset((size.width - pageNoPainter.width) * 0.5, pageNoY - pageNoPainter.height),
  );

  final Paint edgeShadePaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(size.width * 0.985, 0),
      Offset(size.width, 0),
      [Colors.black.withOpacity(0.07), Colors.transparent],
      const [0.0, 1.0],
    );
  canvas.drawRect(pageRect, edgeShadePaint);

  return recorder
      .endRecording()
      .toImage(size.width.round(), size.height.round());
}

void disposePageImages(Iterable<ui.Image> images) {
  for (final ui.Image image in images) {
    image.dispose();
  }
}

class PageCurlPainter extends CustomPainter {
  const PageCurlPainter({
    required this.currentImage,
    required this.belowImage,
    required this.backFaceImage,
    required this.geometry,
    required this.shadowStrength,
    required this.shadowWidth,
    required this.highlightStrength,
  });

  final ui.Image currentImage;
  final ui.Image? belowImage;
  final ui.Image? backFaceImage;
  final CurlGeometry? geometry;

  final double shadowStrength;
  final double shadowWidth;
  final double highlightStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect pageRect = Offset.zero & size;

    if (geometry == null || belowImage == null) {
      canvas.drawImage(currentImage, Offset.zero, Paint());
      _drawIdleEdgeShadow(canvas, size);
      return;
    }

    final CurlGeometry g = geometry!;
    final ui.Image flapBackImage = backFaceImage ?? belowImage!;
    if (!g.hasCurl) {
      canvas.drawImage(currentImage, Offset.zero, Paint());
      return;
    }

    final Path reflectedCurlPath = _buildReflectedCurlPath(g, size);
    final double backMix = Curves.easeInOut.transform(g.progress.clamp(0.0, 1.0));
    final double frontHintOpacity = (1 - backMix) * 0.30;
    final double backFaceOpacity = 0.55 + backMix * 0.40;

    // Layer 4: below page + projection shadow.
    canvas.drawImage(belowImage!, Offset.zero, Paint());
    _drawProjectionShadow(canvas, size, g);

    // Layer 1: stationary visible part of current page.
    canvas.save();
    canvas.clipPath(g.stationaryPath);
    canvas.drawImage(currentImage, Offset.zero, Paint());
    _drawFoldEdgeShadow(canvas, size, g);
    canvas.restore();

    // Layer 2: a thin front-face remnant near the lifted area.
    if (frontHintOpacity > 0.01) {
      canvas.saveLayer(pageRect, Paint());
      canvas.clipPath(g.curlPath);
      canvas.drawImage(
        currentImage,
        Offset.zero,
        Paint()..color = Colors.white.withOpacity(frontHintOpacity),
      );
      _drawCurlFrontHighlight(canvas, size, g);
      canvas.restore();
    }

    // Layer 3: curled back face with mirrored content and independent lighting.
    canvas.saveLayer(pageRect, Paint());
    canvas.clipPath(reflectedCurlPath);

    canvas.save();
    _applyReflection(canvas, g.mid, g.normal);
    canvas.drawImage(
      flapBackImage,
      Offset.zero,
      Paint()..color = Colors.white.withOpacity(backFaceOpacity),
    );
    canvas.restore();

    _drawBackFaceTone(canvas, size, g, amount: 0.7 + backMix * 0.6);
    _drawBackFaceHighlight(canvas, size, g, amount: 0.5 + backMix * 0.8);

    canvas.restore();

    _drawPaperContour(canvas, g);
  }

  Path _buildReflectedCurlPath(CurlGeometry g, Size size) {
    if (g.curlPolygon.length < 3) {
      return Path();
    }
    final List<Offset> reflected = g.curlPolygon
        .map((Offset p) => _reflectPoint(p, g.mid, g.normal))
        .toList(growable: false);
    if (reflected.length < 3) {
      return Path();
    }
    final Path reflectedPath = Path()..addPolygon(reflected, true);
    final Path pagePath = Path()..addRect(Offset.zero & size);
    return Path.combine(PathOperation.intersect, pagePath, reflectedPath);
  }

  Offset _reflectPoint(Offset p, Offset mid, Offset normal) {
    final double d = (p.dx - mid.dx) * normal.dx + (p.dy - mid.dy) * normal.dy;
    return p - normal * (2 * d);
  }

  void _applyReflection(Canvas canvas, Offset mid, Offset normal) {
    final double angle = math.atan2(normal.dy, normal.dx);
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(angle);
    canvas.scale(-1, 1);
    canvas.rotate(-angle);
    canvas.translate(-mid.dx, -mid.dy);
  }

  void _drawProjectionShadow(Canvas canvas, Size size, CurlGeometry g) {
    final double width =
        (shadowWidth * (0.75 + g.progress * 0.9)).clamp(8.0, size.width * 0.5);
    final double opacity =
        (0.10 + 0.28 * g.progress) * shadowStrength.clamp(0.0, 2.0);

    canvas.save();
    canvas.clipPath(g.curlPath);
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-width, 0),
        Offset(0, 0),
        [Colors.black.withOpacity(opacity), Colors.transparent],
        const [0.0, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
      paint,
    );
    canvas.restore();
  }

  void _drawFoldEdgeShadow(Canvas canvas, Size size, CurlGeometry g) {
    final double width =
        (shadowWidth * (0.70 + g.progress * 0.75)).clamp(6.0, size.width * 0.48);

    final double angleFactor = (1 - g.normal.dx.abs()).clamp(0.2, 1.0);
    final double opacity =
        (0.08 + 0.34 * g.progress * angleFactor) * shadowStrength.clamp(0.0, 2.0);

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(-width, 0),
        [Colors.black.withOpacity(opacity), Colors.transparent],
        const [0.0, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawCurlFrontHighlight(Canvas canvas, Size size, CurlGeometry g) {
    final double width =
        (shadowWidth * 0.55).clamp(5.0, size.width * 0.35);
    final double angleFactor = (1 - g.normal.dx.abs()).clamp(0.1, 1.0);
    final double opacity =
        (0.10 + 0.28 * angleFactor * g.progress) * highlightStrength.clamp(0.0, 2.0);

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(width, 0),
        [Colors.white.withOpacity(opacity), Colors.transparent],
        const [0.0, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(0, -size.height * 2, width, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawBackFaceTone(
    Canvas canvas,
    Size size,
    CurlGeometry g, {
    double amount = 1.0,
  }) {
    if (amount <= 0) {
      return;
    }
    final double width =
        (shadowWidth * (1.0 + g.progress)).clamp(12.0, size.width * 0.75);
    final double opacity =
        (0.14 + 0.32 * g.progress) * shadowStrength.clamp(0.0, 2.0) * amount;

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-width, 0),
        Offset(width, 0),
        [
          Colors.black.withOpacity(opacity * 0.95),
          Colors.black.withOpacity(opacity * 0.35),
          Colors.transparent,
        ],
        const [0.0, 0.42, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width * 2, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawBackFaceHighlight(
    Canvas canvas,
    Size size,
    CurlGeometry g, {
    double amount = 1.0,
  }) {
    if (amount <= 0) {
      return;
    }
    final double width =
        (shadowWidth * 0.42).clamp(4.0, size.width * 0.25);
    final double opacity =
        (0.06 + 0.20 * (1 - g.normal.dx.abs()) * g.progress) *
            highlightStrength.clamp(0.0, 2.0) *
            amount;

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-width, 0),
        Offset(0, 0),
        [Colors.white.withOpacity(opacity), Colors.transparent],
        const [0.0, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawPaperContour(Canvas canvas, CurlGeometry g) {
    final Offset start = g.foldStart ?? g.mid - g.tangent * 600;
    final Offset end = g.foldEnd ?? g.mid + g.tangent * 600;

    final Paint contourPaint = Paint()
      ..color = Colors.black.withOpacity(0.10 + g.progress * 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, contourPaint);
  }

  void _drawIdleEdgeShadow(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.98, 0),
        Offset(size.width, 0),
        [Colors.black.withOpacity(0.08), Colors.transparent],
        const [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant PageCurlPainter oldDelegate) {
    return oldDelegate.currentImage != currentImage ||
        oldDelegate.belowImage != belowImage ||
        oldDelegate.backFaceImage != backFaceImage ||
        oldDelegate.geometry != geometry ||
        oldDelegate.shadowStrength != shadowStrength ||
        oldDelegate.shadowWidth != shadowWidth ||
        oldDelegate.highlightStrength != highlightStrength;
  }
}
