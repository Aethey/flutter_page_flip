import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Page content blocks — used to build rich pages with text + images.
// ---------------------------------------------------------------------------

sealed class PageContent {
  const PageContent();
}

class TitleBlock extends PageContent {
  const TitleBlock(this.text);
  final String text;
}

class ParagraphBlock extends PageContent {
  const ParagraphBlock(this.text);
  final String text;
}

/// Image block that renders inline within the page flow.
///
/// [bytes] must be valid encoded image data (PNG / JPEG / WebP / etc.).
/// [height] controls the rendered height in logical pixels; if null the image
/// scales proportionally to fill the content width.
class ImageBlock extends PageContent {
  const ImageBlock({required this.bytes, this.height, this.caption});
  final Uint8List bytes;
  final double? height;
  final String? caption;
}

class SpacingBlock extends PageContent {
  const SpacingBlock([this.height = 16]);
  final double height;
}

// ---------------------------------------------------------------------------
// Book page data model.
// ---------------------------------------------------------------------------

@immutable
class BookPage {
  /// Text-only page (backward compatible).
  const BookPage({
    required this.pageNumber,
    this.title = '',
    this.body = '',
    this.contents,
  });

  /// Rich content page built from content blocks.
  const BookPage.rich({
    required this.pageNumber,
    required List<PageContent> this.contents,
  })  : title = '',
        body = '';

  final int pageNumber;
  final String title;
  final String body;

  /// When non-null, the rasterizer uses these blocks instead of [title]/[body].
  final List<PageContent>? contents;
}
