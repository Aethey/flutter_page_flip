import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/src/geometry.dart';

void main() {
  const Size pageSize = Size(400, 600);

  group('clampPointToPage', () {
    test('keeps in-bounds points unchanged', () {
      const Offset point = Offset(120, 200);
      expect(clampPointToPage(point, pageSize), point);
    });

    test('clamps out-of-bounds points onto the page', () {
      expect(
        clampPointToPage(const Offset(-40, 900), pageSize),
        const Offset(0, 600),
      );
    });

    test('allows configured overscroll', () {
      expect(
        clampPointToPage(
          const Offset(-20, 640),
          pageSize,
          overscrollX: 30,
          overscrollY: 50,
        ),
        const Offset(-20, 640),
      );
    });
  });

  group('computeProgress', () {
    const Offset nextCorner = Offset(400, 600);
    const Offset prevCorner = Offset.zero;

    test('returns 0 for a zero-width page', () {
      expect(
        computeProgress(
          const Offset(10, 10),
          Size.zero,
          nextCorner,
          FlipDirection.next,
        ),
        0,
      );
    });

    test('increases as a next-page drag moves left from the corner', () {
      expect(
        computeProgress(nextCorner, pageSize, nextCorner, FlipDirection.next),
        0,
      );
      expect(
        computeProgress(
          const Offset(200, 600),
          pageSize,
          nextCorner,
          FlipDirection.next,
        ),
        0.5,
      );
      expect(
        computeProgress(
          const Offset(0, 600),
          pageSize,
          nextCorner,
          FlipDirection.next,
        ),
        1,
      );
    });

    test('increases as a previous-page drag moves right from the corner', () {
      expect(
        computeProgress(prevCorner, pageSize, prevCorner, FlipDirection.prev),
        0,
      );
      expect(
        computeProgress(
          const Offset(200, 0),
          pageSize,
          prevCorner,
          FlipDirection.prev,
        ),
        0.5,
      );
    });

    test('clamps progress to the zero-to-one range in both directions', () {
      expect(
        computeProgress(
          const Offset(-200, 600),
          pageSize,
          nextCorner,
          FlipDirection.next,
        ),
        1,
      );
      expect(
        computeProgress(
          const Offset(600, 0),
          pageSize,
          prevCorner,
          FlipDirection.prev,
        ),
        1,
      );
      expect(
        computeProgress(
          const Offset(500, 600),
          pageSize,
          nextCorner,
          FlipDirection.next,
        ),
        0,
      );
    });
  });

  group('computeCurlGeometry', () {
    test('builds a curl polygon for a next-page fold', () {
      final CurlGeometry geometry = computeCurlGeometry(
        size: pageSize,
        dragPoint: const Offset(180, 420),
        corner: const Offset(400, 600),
        direction: FlipDirection.next,
        curlRadius: 400,
      );

      expect(geometry.hasCurl, isTrue);
      expect(geometry.progress, greaterThan(0));
      expect(geometry.progress, lessThan(1));
      expect(geometry.curlPolygon, isNotEmpty);
      expect(geometry.foldStart, isNotNull);
      expect(geometry.foldEnd, isNotNull);
    });

    test('limits the touch point to the curl radius', () {
      final CurlGeometry geometry = computeCurlGeometry(
        size: pageSize,
        dragPoint: const Offset(0, 0),
        corner: const Offset(400, 600),
        direction: FlipDirection.next,
        curlRadius: 80,
      );

      expect((geometry.touch - geometry.corner).distance, closeTo(80, 0.001));
    });

    test('reports no curl when the drag rests on the anchor', () {
      for (final (FlipDirection direction, Offset corner)
          in <(FlipDirection, Offset)>[
            (FlipDirection.next, const Offset(400, 0)),
            (FlipDirection.next, const Offset(400, 600)),
            (FlipDirection.next, const Offset(400, 300)),
            (FlipDirection.prev, const Offset(0, 0)),
            (FlipDirection.prev, const Offset(0, 600)),
            (FlipDirection.prev, const Offset(0, 300)),
          ]) {
        final CurlGeometry geometry = computeCurlGeometry(
          size: pageSize,
          dragPoint: corner,
          corner: corner,
          direction: direction,
          curlRadius: 400,
        );

        expect(
          geometry.hasCurl,
          isFalse,
          reason: '$direction at $corner produced a degenerate curl',
        );
        expect(geometry.curlPolygon, isEmpty);
        expect(geometry.progress, 0);
        expect(geometry.foldStart, isNull);
        expect(geometry.foldEnd, isNull);
        expect(geometry.normal.dx.isFinite, isTrue);
        expect(geometry.normal.dy.isFinite, isTrue);
      }
    });

    test('leaves the page untouched when there is no curl', () {
      final CurlGeometry geometry = computeCurlGeometry(
        size: pageSize,
        dragPoint: const Offset(400, 600),
        corner: const Offset(400, 600),
        direction: FlipDirection.next,
        curlRadius: 400,
      );

      expect(
        geometry.stationaryPath.contains(const Offset(399.9, 300)),
        isTrue,
      );
      expect(geometry.stationaryPath.contains(const Offset(0.1, 300)), isTrue);
      expect(geometry.curlPath.contains(const Offset(399.9, 300)), isFalse);
    });

    test('still builds a curl once the drag clears a pixel', () {
      final CurlGeometry geometry = computeCurlGeometry(
        size: pageSize,
        dragPoint: const Offset(396, 600),
        corner: const Offset(400, 600),
        direction: FlipDirection.next,
        curlRadius: 400,
      );

      expect(geometry.hasCurl, isTrue);
      expect(geometry.progress, greaterThan(0));
    });
  });
}
