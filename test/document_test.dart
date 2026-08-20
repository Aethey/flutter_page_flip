import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';

void main() {
  group('BookDocument.text', () {
    test('builds a title and paragraph blocks', () {
      final BookDocument document = BookDocument.text(
        title: '  Chapter 1  ',
        text: 'First paragraph.\n\nSecond paragraph.',
        startPageNumber: 3,
      );

      expect(document.startPageNumber, 3);
      expect(document.contents, hasLength(3));
      expect(document.contents[0], isA<TitleBlock>());
      expect((document.contents[0] as TitleBlock).text, 'Chapter 1');
      expect(document.contents[1], isA<ParagraphBlock>());
      expect((document.contents[1] as ParagraphBlock).text, 'First paragraph.');
      expect(
        (document.contents[2] as ParagraphBlock).text,
        'Second paragraph.',
      );
    });

    test('skips a blank title and empty paragraphs', () {
      final BookDocument document = BookDocument.text(
        title: '   ',
        text: '\n\nOnly one paragraph.\n\n  \n\n',
      );

      expect(document.startPageNumber, 1);
      expect(document.contents, hasLength(1));
      expect(
        (document.contents.single as ParagraphBlock).text,
        'Only one paragraph.',
      );
    });

    test('keeps explicit content lists unchanged', () {
      const BookDocument document = BookDocument(
        contents: <PageContent>[
          TitleBlock('Title'),
          QuoteBlock('Quote', attribution: 'Author'),
          SpacingBlock(12),
        ],
        startPageNumber: 8,
      );

      expect(document.startPageNumber, 8);
      expect(document.contents, hasLength(3));
      expect(document.contents[1], isA<QuoteBlock>());
    });
  });
}
