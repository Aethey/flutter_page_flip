import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';
import 'package:vellum_engine/src/page_content_view.dart';

/// 1x1 transparent PNG.
final Uint8List _png1x1 = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Widget _wrap(BookPage page) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 640,
        child: BookPageContentView(
          page: page,
          typography: const BookTypography(),
          theme: BookTheme.paperYellow,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a legacy title and body', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const BookPage(
          pageNumber: 4,
          title: 'Legacy Title',
          body: 'First paragraph.\n\nSecond paragraph.',
        ),
      ),
    );

    expect(find.text('Legacy Title'), findsOneWidget);
    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(find.text('- 4 -'), findsOneWidget);
  });

  testWidgets('renders rich content blocks', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        BookPage.rich(
          pageNumber: 2,
          contents: <PageContent>[
            const TitleBlock('Rich Title'),
            const ParagraphBlock('Body paragraph'),
            const QuoteBlock('Quoted line', attribution: 'Author'),
            const BulletListBlock(<String>['Item A', 'Item B']),
            ImageBlock(bytes: _png1x1, height: 48, caption: 'A caption'),
            const SpacingBlock(12),
          ],
        ),
      ),
    );

    expect(find.text('Rich Title'), findsOneWidget);
    expect(find.text('Body paragraph'), findsOneWidget);
    expect(find.text('Quoted line'), findsOneWidget);
    expect(find.text('Author'), findsOneWidget);
    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
    expect(find.text('A caption'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('- 2 -'), findsOneWidget);
  });
}
