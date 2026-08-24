import 'dart:math' as math;

import 'package:flutter/material.dart';

enum FlipDirection {
  next,
  prev,
}

/// Smallest distance between the anchor and the drag point that still produces
/// a curl worth drawing, in logical pixels.
const double _minVisibleCurl = 0.75;

@immutable
class CurlGeometry {
  const CurlGeometry({
    required this.pageRect,
    required this.corner,
    required this.rawTouch,
    required this.touch,
    required this.mid,
    required this.normal,
    required this.tangent,
    required this.progress,
    required this.foldAngle,
    required this.curlPolygon,
    required this.curlPath,
    required this.stationaryPath,
    required this.foldStart,
    required this.foldEnd,
  });

  final Rect pageRect;
  final Offset corner;
  final Offset rawTouch;
  final Offset touch;
  final Offset mid;
  final Offset normal;
  final Offset tangent;
  final double progress;
  final double foldAngle;
  final List<Offset> curlPolygon;
  final Path curlPath;
  final Path stationaryPath;
  final Offset? foldStart;
  final Offset? foldEnd;

  bool get hasCurl => curlPolygon.length >= 3;
}

Offset clampPointToPage(
  Offset point,
  Size size, {
  double overscrollX = 0,
  double overscrollY = 0,
}) {
  return Offset(
    point.dx.clamp(-overscrollX, size.width + overscrollX),
    point.dy.clamp(-overscrollY, size.height + overscrollY),
  );
}

double computeProgress(
  Offset touch,
  Size size,
  Offset corner,
  FlipDirection direction,
) {
  if (size.width <= 0) {
    return 0;
  }
  final raw = switch (direction) {
    FlipDirection.next => (corner.dx - touch.dx) / size.width,
    FlipDirection.prev => (touch.dx - corner.dx) / size.width,
  };
  return raw.clamp(0.0, 1.0);
}

CurlGeometry computeCurlGeometry({
  required Size size,
  required Offset dragPoint,
  required Offset corner,
  required FlipDirection direction,
  required double curlRadius,
  double overscrollX = 0,
  double overscrollY = 0,
}) {
  final Rect pageRect = Offset.zero & size;
  final Offset rawTouch = dragPoint;

  Offset touch = clampPointToPage(
    dragPoint,
    size,
    overscrollX: overscrollX,
    overscrollY: overscrollY,
  );

  final Offset fromCorner = touch - corner;
  final double fromCornerDistance = fromCorner.distance;
  final double radius = math.max(1, curlRadius);
  if (fromCornerDistance > radius) {
    touch = corner + fromCorner * (radius / fromCornerDistance);
  }

  final Offset vector = corner - touch;
  final double dist = vector.distance;
  final Path fullPath = Path()..addRect(pageRect);

  // A fold this close to the anchor is sub-pixel. Clipping the page against it
  // yields a degenerate sliver spanning the anchored edge, which the painter
  // still renders as a contour line and a highlight band on a page that should
  // look flat. Report "no curl" so callers fall back to the plain page.
  if (dist < _minVisibleCurl) {
    final Offset flatNormal = direction == FlipDirection.next
        ? const Offset(1, 0)
        : const Offset(-1, 0);
    final Offset flatTangent = Offset(-flatNormal.dy, flatNormal.dx);
    return CurlGeometry(
      pageRect: pageRect,
      corner: corner,
      rawTouch: rawTouch,
      touch: touch,
      mid: corner,
      normal: flatNormal,
      tangent: flatTangent,
      progress: 0,
      foldAngle: math.atan2(flatTangent.dy, flatTangent.dx),
      curlPolygon: const <Offset>[],
      curlPath: Path(),
      stationaryPath: fullPath,
      foldStart: null,
      foldEnd: null,
    );
  }

  final Offset normal = vector / dist;
  final Offset tangent = Offset(-normal.dy, normal.dx);
  final Offset mid = (corner + touch) / 2;

  final List<Offset> curlPolygon = _clipRectWithHalfPlane(pageRect, mid, normal);
  final Path curlPath = Path();
  if (curlPolygon.length >= 3) {
    curlPath.addPolygon(curlPolygon, true);
  }

  final Path stationaryPath = curlPolygon.length >= 3
      ? Path.combine(PathOperation.difference, fullPath, curlPath)
      : fullPath;

  final List<Offset> foldIntersections = _foldLineIntersections(
    pageRect,
    mid,
    normal,
  );
  Offset? foldStart;
  Offset? foldEnd;
  if (foldIntersections.length >= 2) {
    double maxDistance = -1;
    for (int i = 0; i < foldIntersections.length; i++) {
      for (int j = i + 1; j < foldIntersections.length; j++) {
        final double d = (foldIntersections[i] - foldIntersections[j]).distance;
        if (d > maxDistance) {
          maxDistance = d;
          foldStart = foldIntersections[i];
          foldEnd = foldIntersections[j];
        }
      }
    }
  }

  final double progress = computeProgress(touch, size, corner, direction);

  return CurlGeometry(
    pageRect: pageRect,
    corner: corner,
    rawTouch: rawTouch,
    touch: touch,
    mid: mid,
    normal: normal,
    tangent: tangent,
    progress: progress,
    foldAngle: math.atan2(tangent.dy, tangent.dx),
    curlPolygon: curlPolygon,
    curlPath: curlPath,
    stationaryPath: stationaryPath,
    foldStart: foldStart,
    foldEnd: foldEnd,
  );
}

List<Offset> _clipRectWithHalfPlane(Rect rect, Offset mid, Offset normal) {
  final List<Offset> corners = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
  final List<Offset> output = [];

  double signedDistance(Offset p) {
    return (p.dx - mid.dx) * normal.dx + (p.dy - mid.dy) * normal.dy;
  }

  for (int i = 0; i < corners.length; i++) {
    final Offset current = corners[i];
    final Offset previous = corners[(i - 1 + corners.length) % corners.length];

    final double dCurrent = signedDistance(current);
    final double dPrevious = signedDistance(previous);

    final bool currentInside = dCurrent >= 0;
    final bool previousInside = dPrevious >= 0;

    if (currentInside != previousInside) {
      final double t = dPrevious / (dPrevious - dCurrent);
      final Offset intersection = Offset(
        previous.dx + (current.dx - previous.dx) * t,
        previous.dy + (current.dy - previous.dy) * t,
      );
      output.add(intersection);
    }

    if (currentInside) {
      output.add(current);
    }
  }

  return output;
}

List<Offset> _foldLineIntersections(Rect rect, Offset mid, Offset normal) {
  final List<Offset> result = [];

  double signedDistance(Offset p) {
    return (p.dx - mid.dx) * normal.dx + (p.dy - mid.dy) * normal.dy;
  }

  void addPoint(Offset p) {
    const double tolerance = 0.5;
    final bool exists = result.any((e) => (e - p).distance <= tolerance);
    if (!exists) {
      result.add(p);
    }
  }

  final List<(Offset, Offset)> edges = [
    (rect.topLeft, rect.topRight),
    (rect.topRight, rect.bottomRight),
    (rect.bottomRight, rect.bottomLeft),
    (rect.bottomLeft, rect.topLeft),
  ];

  for (final (Offset a, Offset b) in edges) {
    final double da = signedDistance(a);
    final double db = signedDistance(b);

    if (da.abs() < 0.0001) {
      addPoint(a);
    }
    if (db.abs() < 0.0001) {
      addPoint(b);
    }

    final bool intersects = (da < 0 && db > 0) || (da > 0 && db < 0);
    if (intersects) {
      final double t = da / (da - db);
      final Offset intersection = Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      );
      addPoint(intersection);
    }
  }

  return result;
}
