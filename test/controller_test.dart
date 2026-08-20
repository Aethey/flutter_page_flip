import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';

void main() {
  BookPage page(int number) =>
      BookPage(pageNumber: number, title: 'Page $number', body: 'Body $number');

  group('PageCurlController', () {
    test('manual mode reports the supplied page count', () {
      final PageCurlController controller = PageCurlController(
        pages: <BookPage>[page(1), page(2), page(3)],
      );

      expect(controller.totalPages, 3);
      expect(controller.usesBuilder, isFalse);
      expect(controller.document, isNull);
    });

    test('builder mode reports pageCount immediately', () {
      final PageCurlController controller = PageCurlController.builder(
        pageCount: 40,
        pageBuilder: (int index) => page(index + 1),
      );

      expect(controller.totalPages, 40);
      expect(controller.usesBuilder, isTrue);
    });

    test('document mode starts with an unresolved page count', () {
      final PageCurlController controller = PageCurlController.document(
        document: BookDocument.text(title: 'Chapter', text: 'Hello'),
      );

      expect(controller.totalPages, 0);
      expect(controller.document, isNotNull);
    });

    test('switching data sources clears the previous mode', () {
      final PageCurlController controller = PageCurlController.document(
        document: BookDocument.text(text: 'Hello'),
      );

      controller.pages = <BookPage>[page(1), page(2)];
      expect(controller.document, isNull);
      expect(controller.usesBuilder, isFalse);
      expect(controller.totalPages, 2);

      controller.setBuilder(
        pageCount: 9,
        pageBuilder: (int index) => page(index + 1),
      );
      expect(controller.document, isNull);
      expect(controller.pages, isEmpty);
      expect(controller.usesBuilder, isTrue);
      expect(controller.totalPages, 9);
    });

    test('config assignment notifies listeners', () {
      final PageCurlController controller = PageCurlController(
        pages: <BookPage>[page(1)],
      );
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.config = controller.config.copyWith(shadowStrength: 0.2);

      expect(controller.config.shadowStrength, 0.2);
      expect(notifications, 1);
    });

    test('navigation APIs increment the command version', () {
      final PageCurlController controller = PageCurlController(
        pages: <BookPage>[page(1), page(2), page(3)],
      );
      int notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.navigationCommandVersion, 0);

      controller.nextPage();
      controller.previousPage(animated: false);
      controller.jumpToPage(2);
      controller.animateToPage(0);

      expect(controller.navigationCommandVersion, 4);
      expect(notifications, 4);
    });
  });
}
