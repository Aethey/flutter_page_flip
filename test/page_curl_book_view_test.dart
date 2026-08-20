import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';

BookPage _page(int number, String title) {
  return BookPage(pageNumber: number, title: title, body: 'Body for $title');
}

Widget _wrap(
  PageCurlController controller, {
  int initialPage = 0,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 420,
        height: 720,
        child: PageCurlBookView(
          controller: controller,
          initialPage: initialPage,
          onPageChanged: onPageChanged,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (int i = 0; i < maxPumps; i++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration frame = const Duration(milliseconds: 16),
}) async {
  Duration elapsed = Duration.zero;
  while (elapsed < duration) {
    final Duration remaining = duration - elapsed;
    final Duration step = remaining < frame ? remaining : frame;
    await tester.pump(step);
    elapsed += step;
  }
}

Finder _pageDragZone() {
  return find.byWidgetPredicate(
    (Widget widget) => widget is GestureDetector && widget.onPanStart != null,
    description: 'active page drag zone',
  );
}

void main() {
  testWidgets('renders a manual page', (WidgetTester tester) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await _pumpUntilFound(tester, find.text('First Page'));

    expect(find.text('First Page'), findsOneWidget);
    expect(find.text('Second Page'), findsNothing);
  });

  testWidgets('honors initialPage', (WidgetTester tester) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller, initialPage: 1));
    await _pumpUntilFound(tester, find.text('Second Page'));

    expect(find.text('Second Page'), findsOneWidget);
  });

  testWidgets('builder mode honors initialPage', (WidgetTester tester) async {
    final PageCurlController controller = PageCurlController.builder(
      pageCount: 5,
      pageBuilder: (int index) => _page(index + 1, 'Builder ${index + 1}'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller, initialPage: 3));
    await _pumpUntilFound(tester, find.text('Builder 4'));

    expect(find.text('Builder 4'), findsOneWidget);
    expect(find.text('Builder 1'), findsNothing);
  });

  testWidgets('jumpToPage reports onPageChanged', (WidgetTester tester) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[
        _page(1, 'First Page'),
        _page(2, 'Second Page'),
        _page(3, 'Third Page'),
      ],
    );
    addTearDown(controller.dispose);

    final List<int> changed = <int>[];
    await tester.pumpWidget(_wrap(controller, onPageChanged: changed.add));
    await _pumpUntilFound(tester, find.text('First Page'));

    controller.jumpToPage(2);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Third Page'));

    expect(changed, <int>[2]);
    expect(find.text('First Page'), findsNothing);
  });

  testWidgets('nextPage without animation advances one page', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await _pumpUntilFound(tester, find.text('First Page'));

    controller.nextPage(animated: false);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Second Page'));

    expect(find.text('Second Page'), findsOneWidget);
  });

  testWidgets('animated nextPage changes the logical page only when complete', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);
    final List<int> changed = <int>[];

    await tester.pumpWidget(_wrap(controller, onPageChanged: changed.add));
    await _pumpUntilFound(tester, find.text('First Page'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    controller.nextPage();
    await tester.pump();
    await _pumpFor(tester, const Duration(milliseconds: 120));

    expect(changed, isEmpty);

    await _pumpFor(tester, const Duration(milliseconds: 600));

    expect(changed, <int>[1]);
    expect(find.text('Second Page'), findsOneWidget);
    expect(find.text('First Page'), findsNothing);
  });

  testWidgets('short drag returns to the current page without a callback', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);
    final List<int> changed = <int>[];

    await tester.pumpWidget(_wrap(controller, onPageChanged: changed.add));
    await _pumpUntilFound(tester, find.text('First Page'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    final Finder dragZone = _pageDragZone();
    expect(dragZone, findsOneWidget);
    final Rect zone = tester.getRect(dragZone);
    final TestGesture gesture = await tester.startGesture(
      Offset(zone.right - 4, zone.center.dy),
    );
    await gesture.moveBy(const Offset(-36, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.moveBy(const Offset(36, 0));
    await gesture.up();
    await tester.pump();

    expect(changed, isEmpty);

    await _pumpFor(tester, const Duration(milliseconds: 800));

    expect(changed, isEmpty);
    expect(find.text('First Page'), findsOneWidget);
    expect(find.text('Second Page'), findsNothing);
  });

  testWidgets('long drag commits after the completion animation', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);
    final List<int> changed = <int>[];

    await tester.pumpWidget(_wrap(controller, onPageChanged: changed.add));
    await _pumpUntilFound(tester, find.text('First Page'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    final Finder dragZone = _pageDragZone();
    expect(dragZone, findsOneWidget);
    final Rect zone = tester.getRect(dragZone);
    final TestGesture gesture = await tester.startGesture(
      Offset(zone.right - 4, zone.center.dy),
    );
    await gesture.moveBy(Offset(-zone.width * 2.8, 0));
    await gesture.up();
    await tester.pump();

    expect(changed, isEmpty);

    await _pumpFor(tester, const Duration(milliseconds: 800));

    expect(changed, <int>[1]);
    expect(find.text('Second Page'), findsOneWidget);
    expect(find.text('First Page'), findsNothing);
  });

  testWidgets('previousPage without animation moves back one page', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[_page(1, 'First Page'), _page(2, 'Second Page')],
    );
    addTearDown(controller.dispose);
    final List<int> changed = <int>[];

    await tester.pumpWidget(
      _wrap(controller, initialPage: 1, onPageChanged: changed.add),
    );
    await _pumpUntilFound(tester, find.text('Second Page'));

    controller.previousPage(animated: false);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('First Page'));

    expect(find.text('First Page'), findsOneWidget);
    expect(changed, <int>[0]);
  });

  testWidgets('jumpToPage clamps targets to the available range', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController(
      pages: <BookPage>[
        _page(1, 'First Page'),
        _page(2, 'Second Page'),
        _page(3, 'Third Page'),
      ],
    );
    addTearDown(controller.dispose);
    final List<int> changed = <int>[];

    await tester.pumpWidget(_wrap(controller, onPageChanged: changed.add));
    await _pumpUntilFound(tester, find.text('First Page'));

    controller.jumpToPage(99);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Third Page'));
    controller.jumpToPage(-10);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('First Page'));

    expect(changed, <int>[2, 0]);
  });

  testWidgets('builder mode loads a requested page', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController.builder(
      pageCount: 5,
      pageBuilder: (int index) => _page(index + 1, 'Builder ${index + 1}'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await _pumpUntilFound(tester, find.text('Builder 1'));

    expect(controller.totalPages, 5);
    expect(find.text('Builder 1'), findsOneWidget);
  });

  testWidgets('builder mode waits for asynchronous pages', (
    WidgetTester tester,
  ) async {
    final Map<int, Completer<BookPage>> pending = <int, Completer<BookPage>>{};
    final List<int> requested = <int>[];
    final PageCurlController controller = PageCurlController.builder(
      pageCount: 3,
      pageBuilder: (int index) {
        requested.add(index);
        return (pending[index] ??= Completer<BookPage>()).future;
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    expect(requested, containsAll(<int>[0, 1]));
    expect(find.text('Async 1'), findsNothing);

    pending[1]!.complete(_page(2, 'Async 2'));
    pending[0]!.complete(_page(1, 'Async 1'));
    await _pumpUntilFound(tester, find.text('Async 1'));

    expect(find.text('Async 1'), findsOneWidget);
    expect(requested.where((int index) => index == 0), hasLength(1));
  });

  testWidgets('disposing while builder pages are pending is safe', (
    WidgetTester tester,
  ) async {
    final Map<int, Completer<BookPage>> pending = <int, Completer<BookPage>>{};
    final PageCurlController controller = PageCurlController.builder(
      pageCount: 2,
      pageBuilder:
          (int index) => (pending[index] ??= Completer<BookPage>()).future,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    for (final MapEntry<int, Completer<BookPage>> entry in pending.entries) {
      entry.value.complete(_page(entry.key + 1, 'Late ${entry.key + 1}'));
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('document mode paginates and renders text', (
    WidgetTester tester,
  ) async {
    final PageCurlController controller = PageCurlController.document(
      document: BookDocument.text(
        title: 'Auto Title',
        text: 'A document that the SDK should paginate automatically.',
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await _pumpUntilFound(tester, find.text('Auto Title'));

    expect(controller.totalPages, greaterThan(0));
    expect(find.textContaining('paginate automatically'), findsOneWidget);
  });

  testWidgets('document mode honors initialPage after pagination', (
    WidgetTester tester,
  ) async {
    final String longText =
        List<String>.filled(
          120,
          'Automatic document pagination content. ',
        ).join();
    final PageCurlController controller = PageCurlController.document(
      document: BookDocument.text(text: longText),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller, initialPage: 1));
    await _pumpUntilFound(tester, find.text('- 2 -'));

    expect(controller.totalPages, greaterThan(1));
    expect(find.text('- 2 -'), findsOneWidget);
    expect(find.text('- 1 -'), findsNothing);
  });
}
