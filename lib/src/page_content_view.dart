import 'package:flutter/material.dart';

import 'page_curl_config.dart';
import 'pages.dart';

class BookPageContentView extends StatelessWidget {
  const BookPageContentView({
    super.key,
    required this.page,
    required this.typography,
    required this.theme,
    this.interactiveOnly = false,
  });

  final BookPage page;
  final BookTypography typography;
  final BookTheme theme;
  final bool interactiveOnly;

  @override
  Widget build(BuildContext context) {
    final List<Widget> blocks =
        page.contents != null && page.contents!.isNotEmpty
            ? _buildRichBlocks(page.contents!)
            : _buildLegacyBlocks(page);

    if (interactiveOnly) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          typography.horizontalPadding,
          typography.topPadding,
          typography.horizontalPadding,
          typography.bottomPadding + typography.pageNumberSize + 10,
        ),
        child: SelectionArea(
          child: ListView(
            padding: EdgeInsets.zero,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            children: blocks,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.pageColor,
        gradient:
            theme.pageColorEnd == null || theme.pageColorEnd == theme.pageColor
                ? null
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[theme.pageColor, theme.pageColorEnd!],
                ),
        border:
            theme.borderColor == null || theme.borderWidth <= 0
                ? null
                : Border.all(
                  color: theme.borderColor!,
                  width: theme.borderWidth,
                ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (theme.vignetteOpacity > 0.001)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.72, -0.84),
                    radius: 1.15,
                    colors: <Color>[
                      Colors.white.withValues(alpha: theme.vignetteOpacity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              typography.horizontalPadding,
              typography.topPadding,
              typography.horizontalPadding,
              typography.bottomPadding + typography.pageNumberSize + 10,
            ),
            child: SelectionArea(
              child: ListView(
                padding: EdgeInsets.zero,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                children: blocks,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: typography.bottomPadding,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '- ${page.pageNumber} -',
                  style: TextStyle(
                    fontSize: typography.pageNumberSize,
                    color: theme.pageNumberColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (theme.edgeShadeOpacity > 0.001)
            IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: theme.edgeShadeOpacity),
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

  List<Widget> _buildLegacyBlocks(BookPage page) {
    final List<Widget> widgets = <Widget>[];
    if (page.title.trim().isNotEmpty) {
      widgets.add(_buildTitle(page.title.trim()));
    }

    final List<String> paragraphs = page.body.split('\n\n');
    for (final String paragraph in paragraphs) {
      final String trimmed = paragraph.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      widgets.add(_buildParagraph(trimmed));
    }
    return widgets;
  }

  List<Widget> _buildRichBlocks(List<PageContent> contents) {
    final List<Widget> widgets = <Widget>[];
    for (final PageContent block in contents) {
      switch (block) {
        case TitleBlock(:final text):
          widgets.add(_buildTitle(text));
        case ParagraphBlock(:final text):
          widgets.add(_buildParagraph(text));
        case QuoteBlock(:final text, :final attribution):
          widgets.add(_buildQuote(text, attribution));
        case BulletListBlock(:final items):
          widgets.addAll(items.map(_buildBulletItem));
        case ImageBlock(:final bytes, :final height, :final caption):
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: typography.paragraphSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    opacity:
                        interactiveOnly
                            ? const AlwaysStoppedAnimation<double>(0)
                            : null,
                  ),
                  if (caption != null && caption.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        caption.trim(),
                        style: TextStyle(
                          fontSize: typography.bodySize - 2,
                          height: typography.lineHeight,
                          color: theme.captionColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        case SpacingBlock(:final height):
          widgets.add(SizedBox(height: height));
      }
    }
    return widgets;
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: typography.paragraphSpacing),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: typography.titleSize,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: interactiveOnly ? Colors.transparent : theme.titleColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: typography.paragraphSpacing),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: typography.bodySize,
          height: typography.lineHeight,
          color: interactiveOnly ? Colors.transparent : theme.bodyColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildQuote(String text, String? attribution) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: typography.paragraphSpacing),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:
            interactiveOnly
                ? Colors.transparent
                : theme.pageNumberColor.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(
            color:
                interactiveOnly
                    ? Colors.transparent
                    : theme.pageNumberColor.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(
            text,
            style: TextStyle(
              fontSize: typography.bodySize,
              height: typography.lineHeight,
              color: interactiveOnly ? Colors.transparent : theme.bodyColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (attribution != null && attribution.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                attribution.trim(),
                style: TextStyle(
                  fontSize: typography.bodySize - 2,
                  height: typography.lineHeight,
                  color:
                      interactiveOnly ? Colors.transparent : theme.captionColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: typography.paragraphSpacing * 0.75),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              top: typography.bodySize * 0.32,
              right: 10,
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: interactiveOnly ? Colors.transparent : theme.bodyColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: typography.bodySize,
                height: typography.lineHeight,
                color: interactiveOnly ? Colors.transparent : theme.bodyColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
