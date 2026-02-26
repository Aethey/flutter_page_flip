/// Page curl SDK — realistic page-turn animation for Flutter.
///
/// ```dart
/// import 'package:page_demo/page_curl.dart';
///
/// final controller = PageCurlController(
///   pages: [BookPage(pageNumber: 1, title: '...', body: '...')],
///   config: const PageCurlConfig(),
/// );
///
/// PageCurlBookView(controller: controller);
/// ```
library page_curl;

export 'src/page_curl_book.dart' show PageCurlBookView, PageCurlController;
export 'src/page_curl_config.dart' show PageCurlConfig, BookTypography;
export 'src/pages.dart' show BookPage;
