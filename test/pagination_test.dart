import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';
import 'package:vellum_engine/src/pagination.dart';

void main() {
  const Size pageSize = Size(280, 360);
  const BookTypography typography = BookTypography(
    horizontalPadding: 16,
    topPadding: 20,
    bottomPadding: 20,
    titleSize: 22,
    bodySize: 16,
    lineHeight: 1.6,
    paragraphSpacing: 12,
  );

  test('returns no pages for an unusable viewport', () async {
    final List<BookPage> pages = await paginateBookDocument(
      document: BookDocument.text(text: 'Hello'),
      size: const Size(1, 400),
      typography: typography,
    );

    expect(pages, isEmpty);
  });

  test(
    'returns no pages when padding leaves no usable content width',
    () async {
      final List<BookPage> pages = await paginateBookDocument(
        document: BookDocument.text(text: 'Hello'),
        size: const Size(20, 400),
        typography: typography,
      );

      expect(pages, isEmpty);
    },
  );

  test('keeps a short document on a single page', () async {
    final List<BookPage> pages = await paginateBookDocument(
      document: BookDocument.text(
        title: 'Chapter',
        text: 'A short paragraph.',
        startPageNumber: 7,
      ),
      size: pageSize,
      typography: typography,
    );

    expect(pages, hasLength(1));
    expect(pages.single.pageNumber, 7);
    expect(pages.single.contents, isNotNull);
    expect(pages.single.contents!.first, isA<TitleBlock>());
    expect(pages.single.contents!.last, isA<ParagraphBlock>());
  });

  test('splits a long paragraph across multiple pages', () async {
    final String longText = List<String>.filled(80, '翻页动画自动分页测试。').join();
    final List<BookPage> pages = await paginateBookDocument(
      document: BookDocument.text(text: longText),
      size: pageSize,
      typography: typography,
    );

    expect(pages.length, greaterThan(1));
    expect(pages.first.pageNumber, 1);
    expect(pages[1].pageNumber, 2);
    expect(
      pages.every(
        (BookPage page) => page.contents != null && page.contents!.isNotEmpty,
      ),
      isTrue,
    );

    final String reconstructed =
        pages
            .expand((BookPage page) => page.contents ?? const <PageContent>[])
            .whereType<ParagraphBlock>()
            .map((ParagraphBlock block) => block.text)
            .join();
    expect(reconstructed, longText);
  });

  test('preserves quote attribution during pagination', () async {
    final List<BookPage> pages = await paginateBookDocument(
      document: const BookDocument(
        contents: <PageContent>[
          QuoteBlock('Quoted line', attribution: 'Author'),
        ],
      ),
      size: pageSize,
      typography: typography,
    );

    final QuoteBlock quote =
        pages
            .expand((BookPage page) => page.contents ?? const <PageContent>[])
            .whereType<QuoteBlock>()
            .single;
    expect(quote.text, 'Quoted line');
    expect(quote.attribution, 'Author');
  });

  test('keeps attribution only on the final part of a split quote', () async {
    final String longQuote = List<String>.filled(80, '翻页引用内容测试。').join();
    final List<BookPage> pages = await paginateBookDocument(
      document: BookDocument(
        contents: <PageContent>[QuoteBlock(longQuote, attribution: 'Author')],
      ),
      size: pageSize,
      typography: typography,
    );

    final List<QuoteBlock> quotes =
        pages
            .expand((BookPage page) => page.contents ?? const <PageContent>[])
            .whereType<QuoteBlock>()
            .toList();
    expect(quotes.length, greaterThan(1));
    expect(quotes.map((QuoteBlock quote) => quote.text).join(), longQuote);
    expect(
      quotes
          .take(quotes.length - 1)
          .every((QuoteBlock quote) => quote.attribution == null),
      isTrue,
    );
    expect(quotes.last.attribution, 'Author');
  });

  test('paginates mixed content blocks', () async {
    final List<BookPage> pages = await paginateBookDocument(
      document: BookDocument(
        contents: <PageContent>[
          const TitleBlock('Wind through paper'),
          const ParagraphBlock('A paragraph that should stay with the title.'),
          const QuoteBlock(
            'A good page turn should not hunt pixels.',
            attribution: 'Note',
          ),
          const BulletListBlock(<String>['Auto pagination', '', 'Images']),
          ImageBlock(bytes: Uint8List(0), height: 80, caption: 'Caption'),
          const SpacingBlock(24),
          const ParagraphBlock('Trailing body text after the image.'),
        ],
      ),
      size: pageSize,
      typography: typography,
    );

    expect(pages, isNotEmpty);
    final List<PageContent> blocks =
        pages
            .expand((BookPage page) => page.contents ?? const <PageContent>[])
            .toList();

    expect(blocks.whereType<TitleBlock>(), isNotEmpty);
    expect(blocks.whereType<QuoteBlock>(), isNotEmpty);
    expect(blocks.whereType<BulletListBlock>(), isNotEmpty);
    expect(blocks.whereType<ImageBlock>(), isNotEmpty);
    expect(
      blocks.whereType<BulletListBlock>().every(
        (BulletListBlock block) =>
            block.items.every((String item) => item.isNotEmpty),
      ),
      isTrue,
    );
  });

  test('still emits one page for an empty document', () async {
    final List<BookPage> pages = await paginateBookDocument(
      document: const BookDocument(contents: <PageContent>[]),
      size: pageSize,
      typography: typography,
    );

    expect(pages, hasLength(1));
    expect(pages.single.contents, isEmpty);
  });
}
