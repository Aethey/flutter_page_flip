import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'geometry.dart';
import 'page_curl_config.dart';
import 'pages.dart';

// ---------------------------------------------------------------------------
// Page rasterization — converts BookPage → ui.Image for the curl painter.
// ---------------------------------------------------------------------------

Future<ui.Image> rasterizePageImage({
  required Size size,
  required BookPage page,
  required BookTypography typography,
  required BookTheme theme,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect pageRect = Offset.zero & size;

  _drawPageBackground(canvas, size, pageRect, theme);

  if (theme.realisticTexture) {
    _drawRealisticTexture(canvas, size, page.pageNumber);
  }

  final double contentWidth = size.width - typography.horizontalPadding * 2;
  final double startX = typography.horizontalPadding;
  double cursorY = typography.topPadding;

  if (page.contents != null && page.contents!.isNotEmpty) {
    cursorY = await _renderBlocks(
      canvas,
      page.contents!,
      typography,
      theme,
      size,
      contentWidth,
      startX,
      cursorY,
    );
  } else {
    cursorY = _renderLegacyText(
      canvas,
      page,
      typography,
      theme,
      contentWidth,
      startX,
      cursorY,
    );
  }

  _drawPageNumber(
    canvas,
    page.pageNumber,
    typography,
    theme,
    size,
    contentWidth,
  );
  _drawEdgeShade(canvas, size, pageRect, theme);

  return recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
}

// ---------------------------------------------------------------------------
// Background / footer / edge shade (shared by both paths).
// ---------------------------------------------------------------------------

void _drawPageBackground(
  Canvas canvas,
  Size size,
  Rect pageRect,
  BookTheme theme,
) {
  final Color end = theme.pageColorEnd ?? theme.pageColor;
  if (theme.pageColor == end) {
    canvas.drawRect(pageRect, Paint()..color = theme.pageColor);
  } else {
    canvas.drawRect(
      pageRect,
      Paint()
        ..shader = ui.Gradient.linear(
          pageRect.topLeft,
          pageRect.bottomRight,
          [theme.pageColor, end],
          const [0.0, 1.0],
        ),
    );
  }

  if (theme.vignetteOpacity > 0.001) {
    canvas.drawRect(
      pageRect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.12, size.height * 0.08),
          size.longestSide * 1.1,
          [
            Colors.white.withValues(alpha: theme.vignetteOpacity),
            Colors.transparent,
          ],
          const [0.0, 1.0],
        ),
    );
  }

  if (theme.borderColor != null && theme.borderWidth > 0) {
    canvas.drawRect(
      pageRect.deflate(theme.borderWidth * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.borderWidth
        ..color = theme.borderColor!,
    );
  }
}

void _drawPageNumber(
  Canvas canvas,
  int pageNumber,
  BookTypography typography,
  BookTheme theme,
  Size size,
  double contentWidth,
) {
  final TextPainter p = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: '- $pageNumber -',
      style: TextStyle(
        fontSize: typography.pageNumberSize,
        color: theme.pageNumberColor,
        letterSpacing: 1.2,
      ),
    ),
  )..layout(maxWidth: contentWidth);
  final double y = size.height - typography.bottomPadding;
  p.paint(canvas, Offset((size.width - p.width) * 0.5, y - p.height));
}

void _drawEdgeShade(Canvas canvas, Size size, Rect pageRect, BookTheme theme) {
  if (theme.edgeShadeOpacity < 0.001) return;
  canvas.drawRect(
    pageRect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.985, 0),
        Offset(size.width, 0),
        [
          Colors.black.withValues(alpha: theme.edgeShadeOpacity),
          Colors.transparent,
        ],
        const [0.0, 1.0],
      ),
  );
}

// ---------------------------------------------------------------------------
// Procedural paper texture (realistic theme only).
// ---------------------------------------------------------------------------

void _drawRealisticTexture(Canvas canvas, Size size, int seed) {
  final math.Random rng = math.Random(seed * 7919);

  // Paper grain — tiny dots with color variation.
  final Paint grain = Paint()..style = PaintingStyle.fill;
  for (int i = 0; i < 900; i++) {
    final double x = rng.nextDouble() * size.width;
    final double y = rng.nextDouble() * size.height;
    final double r = 0.3 + rng.nextDouble() * 0.7;
    if (rng.nextBool()) {
      grain.color = Color.fromRGBO(0, 0, 0, 0.012 + rng.nextDouble() * 0.018);
    } else {
      grain.color = Color.fromRGBO(
        255,
        255,
        255,
        0.018 + rng.nextDouble() * 0.025,
      );
    }
    canvas.drawCircle(Offset(x, y), r, grain);
  }

  // Paper fibers — short thin lines.
  final Paint fiber =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3;
  for (int i = 0; i < 70; i++) {
    final double x = rng.nextDouble() * size.width;
    final double y = rng.nextDouble() * size.height;
    final double angle = rng.nextDouble() * math.pi;
    final double len = 4 + rng.nextDouble() * 14;
    fiber.color = Color.fromRGBO(
      195 + rng.nextInt(45),
      185 + rng.nextInt(35),
      165 + rng.nextInt(25),
      0.12 + rng.nextDouble() * 0.14,
    );
    canvas.drawLine(
      Offset(x, y),
      Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
      fiber,
    );
  }

  // Foxing / age spots.
  for (int i = 0; i < 6; i++) {
    final double cx = size.width * 0.1 + rng.nextDouble() * size.width * 0.8;
    final double cy = size.height * 0.1 + rng.nextDouble() * size.height * 0.8;
    final double rx = 2.5 + rng.nextDouble() * 5;
    final double ry = 2.5 + rng.nextDouble() * 5;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = Color.fromRGBO(
          135 + rng.nextInt(45),
          115 + rng.nextInt(35),
          75 + rng.nextInt(35),
          0.035 + rng.nextDouble() * 0.04,
        ),
    );
  }

  // Stronger edge darkening.
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.45),
        size.longestSide * 0.65,
        [Colors.transparent, Colors.black.withValues(alpha: 0.055)],
        const [0.55, 1.0],
      ),
  );
}

// ---------------------------------------------------------------------------
// Legacy text-only rendering (title + body string).
// ---------------------------------------------------------------------------

double _renderLegacyText(
  Canvas canvas,
  BookPage page,
  BookTypography typography,
  BookTheme theme,
  double contentWidth,
  double startX,
  double cursorY,
) {
  final TextPainter titlePainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 2,
    text: TextSpan(
      text: page.title,
      style: TextStyle(
        fontSize: typography.titleSize,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: theme.titleColor,
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
          color: theme.bodyColor,
          letterSpacing: 0.1,
        ),
      ),
    )..layout(maxWidth: contentWidth);
    bodyPainter.paint(canvas, Offset(startX, cursorY));
    cursorY += bodyPainter.height + typography.paragraphSpacing;
  }

  return cursorY;
}

// ---------------------------------------------------------------------------
// Block-based rendering (rich content: text + images + spacing).
// ---------------------------------------------------------------------------

Future<double> _renderBlocks(
  Canvas canvas,
  List<PageContent> blocks,
  BookTypography typography,
  BookTheme theme,
  Size size,
  double contentWidth,
  double startX,
  double cursorY,
) async {
  final double maxY = size.height - typography.bottomPadding - 20;

  for (final PageContent block in blocks) {
    if (cursorY >= maxY) break;

    switch (block) {
      case TitleBlock(:final text):
        final TextPainter p = TextPainter(
          textDirection: TextDirection.ltr,
          maxLines: 2,
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: typography.titleSize,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: theme.titleColor,
              letterSpacing: 0.2,
            ),
          ),
        )..layout(maxWidth: contentWidth);
        p.paint(canvas, Offset(startX, cursorY));
        cursorY += p.height + typography.paragraphSpacing;

      case ParagraphBlock(:final text):
        final TextPainter p = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: typography.bodySize,
              height: typography.lineHeight,
              color: theme.bodyColor,
              letterSpacing: 0.1,
            ),
          ),
        )..layout(maxWidth: contentWidth);
        p.paint(canvas, Offset(startX, cursorY));
        cursorY += p.height + typography.paragraphSpacing;

      case QuoteBlock(:final text, :final attribution):
        final TextPainter quotePainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: typography.bodySize,
              height: typography.lineHeight,
              color: theme.bodyColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        )..layout(maxWidth: contentWidth - 28);
        final double quoteHeight = quotePainter.height + 24;
        final Rect quoteRect = Rect.fromLTWH(
          startX,
          cursorY,
          contentWidth,
          quoteHeight,
        );
        canvas.drawRect(
          quoteRect,
          Paint()..color = theme.pageNumberColor.withValues(alpha: 0.08),
        );
        canvas.drawRect(
          Rect.fromLTWH(startX, cursorY, 3, quoteHeight),
          Paint()..color = theme.pageNumberColor.withValues(alpha: 0.5),
        );
        quotePainter.paint(canvas, Offset(startX + 14, cursorY + 12));
        cursorY += quoteHeight;

        if (attribution != null && attribution.isNotEmpty) {
          final TextPainter attributionPainter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: attribution,
              style: TextStyle(
                fontSize: typography.bodySize - 2,
                height: typography.lineHeight,
                color: theme.captionColor,
                letterSpacing: 0.2,
              ),
            ),
          )..layout(maxWidth: contentWidth - 28);
          attributionPainter.paint(canvas, Offset(startX + 14, cursorY + 8));
          cursorY += attributionPainter.height + 8;
        }
        cursorY += typography.paragraphSpacing;

      case BulletListBlock(:final items):
        for (final String item in items) {
          final TextPainter bulletPainter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: item,
              style: TextStyle(
                fontSize: typography.bodySize,
                height: typography.lineHeight,
                color: theme.bodyColor,
                letterSpacing: 0.1,
              ),
            ),
          )..layout(maxWidth: contentWidth - 18);
          final double bulletY = cursorY + typography.bodySize * 0.32;
          canvas.drawCircle(
            Offset(startX + 3, bulletY),
            3,
            Paint()..color = theme.bodyColor,
          );
          bulletPainter.paint(canvas, Offset(startX + 16, cursorY));
          cursorY += bulletPainter.height + typography.paragraphSpacing * 0.75;
        }

      case ImageBlock(:final bytes, :final height, :final caption):
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        final ui.Image img = frame.image;

        final double imgAspect = img.width / img.height;
        final double drawW = contentWidth;
        final double drawH = height ?? (drawW / imgAspect);
        final Rect src = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final Rect dst = Rect.fromLTWH(startX, cursorY, drawW, drawH);

        canvas.save();
        canvas.clipRect(dst);
        canvas.drawImageRect(
          img,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        img.dispose();

        cursorY += drawH + 6;

        if (caption != null && caption.isNotEmpty) {
          final TextPainter cp = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: caption,
              style: TextStyle(
                fontSize: typography.bodySize - 2,
                height: typography.lineHeight,
                color: theme.captionColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          )..layout(maxWidth: contentWidth);
          cp.paint(canvas, Offset(startX, cursorY));
          cursorY += cp.height + typography.paragraphSpacing;
        } else {
          cursorY += typography.paragraphSpacing;
        }

      case SpacingBlock(:final height):
        cursorY += height;
    }
  }

  return cursorY;
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
    required this.backFaceTint,
    this.paintStationaryCurrentPage = true,
    this.paintBelowPageImage = true,
  });

  final ui.Image currentImage;
  final ui.Image? belowImage;
  final ui.Image? backFaceImage;
  final CurlGeometry? geometry;

  final double shadowStrength;
  final double shadowWidth;
  final double highlightStrength;
  final Color backFaceTint;
  final bool paintStationaryCurrentPage;
  final bool paintBelowPageImage;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect pageRect = Offset.zero & size;

    if (geometry == null) {
      if (paintStationaryCurrentPage) {
        canvas.drawImage(currentImage, Offset.zero, Paint());
        _drawIdleEdgeShadow(canvas, size);
      }
      return;
    }

    final CurlGeometry g = geometry!;
    final ui.Image flapBackImage = backFaceImage ?? currentImage;
    if (!g.hasCurl) {
      if (paintStationaryCurrentPage) {
        canvas.drawImage(currentImage, Offset.zero, Paint());
      }
      return;
    }

    final Path reflectedCurlPath = _buildReflectedCurlPath(g, size);
    final double t = Curves.easeInOut.transform(g.progress.clamp(0.0, 1.0));

    // Layer 1: below page visible through the lifted area.
    canvas.save();
    canvas.clipPath(g.curlPath);
    if (paintBelowPageImage && belowImage != null) {
      canvas.drawImage(belowImage!, Offset.zero, Paint());
    }
    _drawProjectionShadow(canvas, size, g);
    canvas.restore();

    // Layer 2: stationary visible part of current page.
    canvas.save();
    canvas.clipPath(g.stationaryPath);
    if (paintStationaryCurrentPage) {
      canvas.drawImage(currentImage, Offset.zero, Paint());
    }
    _drawFoldEdgeShadow(canvas, size, g);
    canvas.restore();

    // Layer 3: curled back face with reflected content, paper tint, and cylinder shading.
    canvas.saveLayer(pageRect, Paint());
    canvas.clipPath(reflectedCurlPath);

    canvas.save();
    _applyReflection(canvas, g.mid, g.normal);
    canvas.drawImage(
      flapBackImage,
      Offset.zero,
      Paint()..color = Colors.white.withValues(alpha: 0.60 + t * 0.35),
    );
    canvas.restore();

    final double tintOpacity = (0.45 - t * 0.20).clamp(0.10, 0.50);
    canvas.drawRect(
      pageRect,
      Paint()..color = backFaceTint.withValues(alpha: tintOpacity),
    );

    _drawBackFaceTone(canvas, size, g, amount: 0.8 + t * 0.5);
    _drawBackFaceHighlight(canvas, size, g, amount: 0.6 + t * 0.7);

    canvas.restore();

    // Layer 4: cylinder highlight along fold line.
    _drawCylinderHighlight(canvas, size, g);

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
    final double width = (shadowWidth * (0.75 + g.progress * 0.9)).clamp(
      8.0,
      size.width * 0.5,
    );
    final double opacity =
        (0.10 + 0.28 * g.progress) * shadowStrength.clamp(0.0, 2.0);

    canvas.save();
    canvas.clipPath(g.curlPath);
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(width, 0),
            [Colors.black.withValues(alpha: opacity), Colors.transparent],
            const [0.0, 1.0],
          );

    canvas.drawRect(
      Rect.fromLTWH(0, -size.height * 2, width, size.height * 4),
      paint,
    );
    canvas.restore();
  }

  void _drawFoldEdgeShadow(Canvas canvas, Size size, CurlGeometry g) {
    final double width = (shadowWidth * (0.70 + g.progress * 0.75)).clamp(
      6.0,
      size.width * 0.48,
    );

    final double angleFactor = (1 - g.normal.dx.abs()).clamp(0.2, 1.0);
    final double opacity =
        (0.08 + 0.34 * g.progress * angleFactor) *
        shadowStrength.clamp(0.0, 2.0);

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(-width, 0),
            [Colors.black.withValues(alpha: opacity), Colors.transparent],
            const [0.0, 1.0],
          );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
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
    final double width = (shadowWidth * (1.0 + g.progress)).clamp(
      12.0,
      size.width * 0.75,
    );
    final double opacity =
        (0.14 + 0.32 * g.progress) * shadowStrength.clamp(0.0, 2.0) * amount;

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-width, 0),
            Offset(0, 0),
            [
              Colors.transparent,
              Colors.black.withValues(alpha: opacity * 0.40),
              Colors.black.withValues(alpha: opacity),
            ],
            const [0.0, 0.50, 1.0],
          );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
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
    final double width = (shadowWidth * 0.42).clamp(4.0, size.width * 0.25);
    final double opacity =
        (0.06 + 0.20 * (1 - g.normal.dx.abs()) * g.progress) *
        highlightStrength.clamp(0.0, 2.0) *
        amount;

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-width, 0),
            Offset(0, 0),
            [
              Colors.transparent,
              Colors.white.withValues(alpha: opacity),
              Colors.transparent,
            ],
            const [0.0, 0.40, 1.0],
          );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawCylinderHighlight(Canvas canvas, Size size, CurlGeometry g) {
    final double width = (shadowWidth * 0.20).clamp(2.0, 12.0);
    final double angleFactor = (1 - g.normal.dx.abs()).clamp(0.15, 1.0);
    final double opacity =
        (0.10 + 0.24 * angleFactor * g.progress) *
        highlightStrength.clamp(0.0, 2.0);

    if (opacity < 0.01) {
      return;
    }

    canvas.save();
    canvas.translate(g.mid.dx, g.mid.dy);
    canvas.rotate(math.atan2(g.normal.dy, g.normal.dx));

    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-width, 0),
            Offset(width, 0),
            [
              Colors.transparent,
              Colors.white.withValues(alpha: opacity),
              Colors.transparent,
            ],
            const [0.0, 0.5, 1.0],
          );

    canvas.drawRect(
      Rect.fromLTWH(-width, -size.height * 2, width * 2, size.height * 4),
      paint,
    );

    canvas.restore();
  }

  void _drawPaperContour(Canvas canvas, CurlGeometry g) {
    final Offset start = g.foldStart ?? g.mid - g.tangent * 600;
    final Offset end = g.foldEnd ?? g.mid + g.tangent * 600;

    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14 + g.progress * 0.10)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, shadowPaint);

    final Offset offset = g.normal * -1.0;
    final Paint edgePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08 + g.progress * 0.06)
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke;
    canvas.drawLine(start + offset, end + offset, edgePaint);
  }

  void _drawIdleEdgeShadow(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(size.width * 0.98, 0),
            Offset(size.width, 0),
            [Colors.black.withValues(alpha: 0.08), Colors.transparent],
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
        oldDelegate.highlightStrength != highlightStrength ||
        oldDelegate.paintStationaryCurrentPage != paintStationaryCurrentPage ||
        oldDelegate.paintBelowPageImage != paintBelowPageImage;
  }
}
