import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'document.dart';
import 'page_curl_config.dart';
import 'pages.dart';

final Map<int, Size> _imageDimensionsCache = <int, Size>{};

Future<List<BookPage>> paginateBookDocument({
  required BookDocument document,
  required Size size,
  required BookTypography typography,
}) async {
  if (size.width <= 1 || size.height <= 1) {
    return const <BookPage>[];
  }

  final _Paginator paginator = _Paginator(
    document: document,
    size: size,
    typography: typography,
  );
  return paginator.paginate();
}

class _Paginator {
  _Paginator({
    required this.document,
    required this.size,
    required this.typography,
  });

  final BookDocument document;
  final Size size;
  final BookTypography typography;

  final List<BookPage> _pages = <BookPage>[];
  final List<PageContent> _currentBlocks = <PageContent>[];

  late int _nextPageNumber = document.startPageNumber;
  late double _cursorY = typography.topPadding;

  double get _contentWidth => size.width - typography.horizontalPadding * 2;

  double get _maxContentBottom => size.height - typography.bottomPadding - 20;

  double get _pageCapacity => _maxContentBottom - typography.topPadding;

  double get _remainingHeight => _maxContentBottom - _cursorY;

  Future<List<BookPage>> paginate() async {
    for (final PageContent block in document.contents) {
      switch (block) {
        case TitleBlock(:final text):
          await _addTextBlock(
            text: text,
            builder: (String value) => TitleBlock(value),
            style: TextStyle(
              fontSize: typography.titleSize,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 2,
          );

        case ParagraphBlock(:final text):
          await _addTextBlock(
            text: text,
            builder: (String value) => ParagraphBlock(value),
            style: TextStyle(
              fontSize: typography.bodySize,
              height: typography.lineHeight,
              letterSpacing: 0.1,
            ),
          );

        case QuoteBlock(:final text, :final attribution):
          await _addTextBlock(
            text: text,
            builder: (String value) => QuoteBlock(value),
            style: TextStyle(
              fontSize: typography.bodySize,
              height: typography.lineHeight,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.1,
            ),
          );
          if (attribution != null && attribution.trim().isNotEmpty) {
            await _addTextBlock(
              text: attribution.trim(),
              builder: (String value) => ParagraphBlock(value),
              style: TextStyle(
                fontSize: typography.bodySize - 2,
                height: typography.lineHeight,
                letterSpacing: 0.2,
              ),
            );
          }

        case BulletListBlock(:final items):
          for (final String item in items) {
            final String trimmed = item.trim();
            if (trimmed.isEmpty) {
              continue;
            }
            await _addTextBlock(
              text: trimmed,
              builder: (String value) => BulletListBlock(<String>[value]),
              style: TextStyle(
                fontSize: typography.bodySize,
                height: typography.lineHeight,
                letterSpacing: 0.1,
              ),
            );
          }

        case ImageBlock():
          await _addImageBlock(block);

        case SpacingBlock(:final height):
          _addSpacing(height);
      }
    }

    _flushPage(force: _pages.isEmpty);
    return List<BookPage>.unmodifiable(_pages);
  }

  Future<void> _addTextBlock({
    required String text,
    required PageContent Function(String value) builder,
    required TextStyle style,
    int? maxLines,
  }) async {
    String remaining = text.trim();
    if (remaining.isEmpty) {
      return;
    }

    while (remaining.isNotEmpty) {
      if (_remainingHeight <= 0) {
        _flushPage();
      }

      final int fit = _maxFittingLength(
        text: remaining,
        style: style,
        maxHeight: _remainingHeight,
        maxLines: maxLines,
      );

      if (fit <= 0) {
        if (_currentBlocks.isNotEmpty) {
          _flushPage();
          continue;
        }

        final int forced = _maxFittingLength(
          text: remaining,
          style: style,
          maxHeight: _pageCapacity,
          maxLines: maxLines,
          allowOverflowFallback: true,
        );
        final int split = forced <= 0 ? remaining.length : forced;
        final String chunk = remaining.substring(0, split).trimRight();
        _pushBlock(builder(chunk), _measureTextHeight(chunk, style, maxLines));
        remaining = remaining.substring(split).trimLeft();
        if (remaining.isNotEmpty) {
          _flushPage();
        }
        continue;
      }

      final int split = _softBreakIndex(remaining, fit);
      final String chunk = remaining.substring(0, split).trimRight();
      if (chunk.isEmpty) {
        final String fallback = remaining.substring(0, fit).trimRight();
        _pushBlock(
          builder(fallback),
          _measureTextHeight(fallback, style, maxLines),
        );
        remaining = remaining.substring(fit).trimLeft();
      } else {
        _pushBlock(builder(chunk), _measureTextHeight(chunk, style, maxLines));
        remaining = remaining.substring(split).trimLeft();
      }

      if (remaining.isNotEmpty) {
        _flushPage();
      }
    }
  }

  Future<void> _addImageBlock(ImageBlock block) async {
    double drawHeight = block.height ?? await _resolveImageHeight(block.bytes);
    drawHeight = drawHeight.clamp(1, _pageCapacity).toDouble();

    double captionHeight = 0;
    if (block.caption != null && block.caption!.trim().isNotEmpty) {
      captionHeight = _measureTextHeight(
        block.caption!.trim(),
        TextStyle(
          fontSize: typography.bodySize - 2,
          height: typography.lineHeight,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final double spacingAfter =
        block.caption != null && block.caption!.trim().isNotEmpty
            ? typography.paragraphSpacing
            : typography.paragraphSpacing;
    double totalHeight = drawHeight + 6 + captionHeight + spacingAfter;

    if (totalHeight > _remainingHeight && _currentBlocks.isNotEmpty) {
      _flushPage();
    }

    if (totalHeight > _remainingHeight) {
      final double maxImageHeight = (_remainingHeight -
              6 -
              captionHeight -
              spacingAfter)
          .clamp(32, _pageCapacity);
      drawHeight = drawHeight.clamp(32, maxImageHeight).toDouble();
      totalHeight = drawHeight + 6 + captionHeight + spacingAfter;
    }

    _pushBlock(
      ImageBlock(
        bytes: block.bytes,
        height: drawHeight,
        caption: block.caption,
      ),
      totalHeight,
    );
  }

  void _addSpacing(double height) {
    if (height <= 0) {
      return;
    }

    final double safeHeight = height.clamp(0, _pageCapacity).toDouble();
    if (_currentBlocks.isEmpty) {
      return;
    }

    if (safeHeight > _remainingHeight) {
      _flushPage();
      return;
    }

    _pushBlock(SpacingBlock(safeHeight), safeHeight);
  }

  void _pushBlock(PageContent block, double height) {
    _currentBlocks.add(block);
    _cursorY += height;
  }

  void _flushPage({bool force = false}) {
    if (_currentBlocks.isEmpty && !force) {
      return;
    }

    _pages.add(
      BookPage.rich(
        pageNumber: _nextPageNumber++,
        contents: List<PageContent>.unmodifiable(_currentBlocks),
      ),
    );
    _currentBlocks.clear();
    _cursorY = typography.topPadding;
  }

  double _measureTextHeight(String text, TextStyle style, [int? maxLines]) {
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      text: TextSpan(text: text, style: style),
    )..layout(maxWidth: _contentWidth);
    return painter.height + typography.paragraphSpacing;
  }

  int _maxFittingLength({
    required String text,
    required TextStyle style,
    required double maxHeight,
    int? maxLines,
    bool allowOverflowFallback = false,
  }) {
    if (text.isEmpty || maxHeight <= 0) {
      return 0;
    }

    int low = 1;
    int high = text.length;
    int best = 0;

    while (low <= high) {
      final int mid = (low + high) >> 1;
      final double height = _measureRawTextHeight(
        text.substring(0, mid),
        style,
        maxLines,
      );
      if (height + typography.paragraphSpacing <= maxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (best == 0 && allowOverflowFallback) {
      return 1;
    }
    return best;
  }

  double _measureRawTextHeight(String text, TextStyle style, int? maxLines) {
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      text: TextSpan(text: text, style: style),
    )..layout(maxWidth: _contentWidth);
    return painter.height;
  }

  int _softBreakIndex(String text, int rawIndex) {
    if (rawIndex >= text.length) {
      return text.length;
    }

    const String breakers = ' \n\t,.;:!?)]}';
    final int minIndex = (rawIndex * 0.7).floor();
    for (int i = rawIndex; i > minIndex; i--) {
      if (breakers.contains(text[i - 1])) {
        return i;
      }
    }
    return rawIndex;
  }

  Future<double> _resolveImageHeight(Uint8List bytes) async {
    final int key = Object.hash(bytes.hashCode, bytes.length);
    final Size? cached = _imageDimensionsCache[key];
    if (cached != null && cached.height > 0) {
      return _contentWidth / (cached.width / cached.height);
    }

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final Size size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    _imageDimensionsCache[key] = size;
    return _contentWidth / (size.width / size.height);
  }
}
