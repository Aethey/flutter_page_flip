import 'package:flutter/foundation.dart';

import 'pages.dart';

@immutable
class BookDocument {
  const BookDocument({required this.contents, this.startPageNumber = 1});

  factory BookDocument.text({
    required String text,
    String? title,
    int startPageNumber = 1,
  }) {
    final List<PageContent> blocks = <PageContent>[];
    if (title != null && title.trim().isNotEmpty) {
      blocks.add(TitleBlock(title.trim()));
    }

    for (final String paragraph in text.split(RegExp(r'\n\s*\n'))) {
      final String trimmed = paragraph.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      blocks.add(ParagraphBlock(trimmed));
    }

    return BookDocument(contents: blocks, startPageNumber: startPageNumber);
  }

  final List<PageContent> contents;
  final int startPageNumber;
}
