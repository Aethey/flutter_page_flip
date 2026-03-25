/// Page curl SDK — realistic page-turn animation for Flutter.
///
/// ```dart
/// import 'package:vellum_engine/page_curl.dart';
///
/// final controller = PageCurlController(
///   pages: [BookPage(pageNumber: 1, title: '...', body: '...')],
///   config: const PageCurlConfig(),
/// );
///
/// PageCurlBookView(controller: controller);
/// ```
library page_curl;

export 'src/page_curl_book.dart'
    show PageCurlBookView, PageCurlController, PageCurlPageBuilder;
export 'src/page_curl_config.dart'
    show PageCurlConfig, BookTypography, BookTheme;
export 'src/document.dart' show BookDocument;
export 'src/pages.dart'
    show
        BookPage,
        PageContent,
        TitleBlock,
        ParagraphBlock,
        QuoteBlock,
        BulletListBlock,
        ImageBlock,
        SpacingBlock;
