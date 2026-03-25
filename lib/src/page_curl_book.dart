import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'geometry.dart';
import 'page_curl_config.dart';
import 'page_curl_painter.dart';
import 'pages.dart';
import 'physics.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class PageCurlController extends ChangeNotifier {
  PageCurlController({
    required List<BookPage> pages,
    PageCurlConfig config = const PageCurlConfig(),
  })  : _pages = List.of(pages),
        _config = config;

  List<BookPage> _pages;
  PageCurlConfig _config;

  List<BookPage> get pages => _pages;
  PageCurlConfig get config => _config;
  int get totalPages => _pages.length;

  set config(PageCurlConfig value) {
    _config = value;
    notifyListeners();
  }

  set pages(List<BookPage> value) {
    _pages = List.of(value);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class PageCurlBookView extends StatefulWidget {
  const PageCurlBookView({
    super.key,
    required this.controller,
    this.onPageChanged,
    this.initialPage = 0,
  });

  final PageCurlController controller;
  final ValueChanged<int>? onPageChanged;
  final int initialPage;

  @override
  State<PageCurlBookView> createState() => _PageCurlBookViewState();
}

// ---------------------------------------------------------------------------
// Internal state
// ---------------------------------------------------------------------------

enum _Flip { idle, dragging, toNext, back, toPrev }

class _DragIntent {
  const _DragIntent({
    required this.direction,
    required this.position,
    required this.anchor,
  });

  final FlipDirection direction;
  final Offset position;
  final Offset anchor;
}

class _PageCurlBookViewState extends State<PageCurlBookView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  final PointerVelocityEstimator _vel = PointerVelocityEstimator();

  _Flip _state = _Flip.idle;
  FlipDirection? _dir;

  int _page = 0;
  Size _vp = Size.zero;

  List<ui.Image> _imgs = <ui.Image>[];
  bool _rasterizing = false;
  int _rasterToken = 0;
  Size _rasterizedSize = Size.zero;
  Size _requestedSize = Size.zero;

  Offset? _drag;
  Offset? _corner;
  Offset? _animFrom;
  Offset? _animTo;
  _DragIntent? _pendingDrag;
  int _animToken = 0;

  PageCurlConfig get _cfg => widget.controller.config;
  List<BookPage> get _pages => widget.controller.pages;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, math.max(0, _pages.length - 1));
    _ac = AnimationController(vsync: this, lowerBound: -0.5, upperBound: 1.5)
      ..addListener(_onAnimTick);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PageCurlBookView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ac.dispose();
    disposePageImages(_imgs);
    super.dispose();
  }

  // ---- controller sync ----------------------------------------------------

  void _onControllerChanged() {
    setState(() {
      if (_page >= _pages.length) {
        _page = math.max(0, _pages.length - 1);
      }
    });
    _rasterizedSize = Size.zero;
    if (_vp.width > 1 && _vp.height > 1) {
      Future<void>.microtask(() => _ensureRasterized(_vp));
    }
  }

  // ---- helpers ------------------------------------------------------------

  bool get _canNext => _page < _pages.length - 1;
  bool get _canPrev => _page > 0;

  bool get _isAnimating =>
      _state == _Flip.back ||
      _state == _Flip.toNext ||
      _state == _Flip.toPrev;

  bool _sameSize(Size a, Size b, [double tol = 0.5]) =>
      (a.width - b.width).abs() <= tol && (a.height - b.height).abs() <= tol;

  double get _curlR => _vp.width <= 0 ? 1 : _vp.width * _cfg.curlRadiusFactor;

  double get _dragOverscrollX => _vp.width * 0.08;

  double get _dragOverscrollY => _vp.height * 0.06;

  double _edgeZoneWidth() {
    final double scaled = math.max(_cfg.edgeZoneWidth, _vp.width * 0.18);
    final double maxWidth = math.max(72, _vp.width * 0.28);
    return scaled.clamp(72, maxWidth).toDouble();
  }

  double _tapZoneWidth() {
    final double scaled = math.max(_edgeZoneWidth(), _vp.width * 0.24);
    final double maxWidth = math.max(96, _vp.width * 0.32);
    return scaled.clamp(96, maxWidth).toDouble();
  }

  // ---- animation tick -----------------------------------------------------

  void _onAnimTick() {
    if (_animFrom == null || _animTo == null) return;
    final double t = _ac.value.clamp(0.0, 1.0);
    setState(() => _drag = Offset.lerp(_animFrom, _animTo, t));
  }

  // ---- rasterization ------------------------------------------------------

  Future<void> _ensureRasterized(Size size) async {
    if (size.width <= 1 || size.height <= 1) return;

    final bool sameReq = _sameSize(_requestedSize, size);
    final bool sameRast =
        _sameSize(_rasterizedSize, size) && _imgs.isNotEmpty;
    if (sameReq && (_rasterizing || sameRast)) return;

    _requestedSize = size;
    final int token = ++_rasterToken;
    if (mounted) setState(() => _rasterizing = true);

    final List<ui.Image> images = <ui.Image>[];
    for (final BookPage page in _pages) {
      images.add(
        await rasterizePageImage(
          size: size,
          page: page,
          typography: _cfg.typography,
          theme: _cfg.theme,
        ),
      );
    }

    if (!mounted || token != _rasterToken) {
      disposePageImages(images);
      return;
    }

    disposePageImages(_imgs);
    setState(() {
      _imgs = images;
      _rasterizedSize = size;
      _rasterizing = false;
      if (_page >= _imgs.length) _page = math.max(0, _imgs.length - 1);
      _resetFlip(keepPage: true);
    });
  }

  // ---- viewport -----------------------------------------------------------

  void _onViewportChanged(Size s) {
    if (_sameSize(_vp, s)) return;
    _vp = s;
    Future<void>.microtask(() => _ensureRasterized(s));
  }

  Offset _edgeAnchorFor(FlipDirection d, double y) {
    final double x = d == FlipDirection.next ? _vp.width : 0;
    return Offset(x, y.clamp(0, _vp.height).toDouble());
  }

  double _edgeAnchorY(double rawY) {
    final double y = rawY.clamp(0, _vp.height).toDouble();
    final double cornerBand = (_vp.height * 0.20).clamp(68, 150).toDouble();
    final double transitionBand =
        (_vp.height * 0.10).clamp(28, 72).toDouble();

    if (y <= cornerBand) {
      return 0;
    }

    final double topTransitionEnd = cornerBand + transitionBand;
    if (y < topTransitionEnd) {
      final double t = ((y - cornerBand) / transitionBand).clamp(0.0, 1.0);
      return ui.lerpDouble(0, y, Curves.easeOut.transform(t)) ?? y;
    }

    final double bottomCornerStart = _vp.height - cornerBand;
    if (y >= bottomCornerStart) {
      return _vp.height;
    }

    final double bottomTransitionStart = bottomCornerStart - transitionBand;
    if (y > bottomTransitionStart) {
      final double t =
          ((y - bottomTransitionStart) / transitionBand).clamp(0.0, 1.0);
      return ui.lerpDouble(y, _vp.height, Curves.easeOut.transform(t)) ?? y;
    }

    return y;
  }

  bool _isSideAnchor(Offset anchor) =>
      anchor.dy > 0.5 && anchor.dy < _vp.height - 0.5;

  Offset _commitTargetFor({
    required FlipDirection direction,
    required Offset anchor,
  }) {
    if (_isSideAnchor(anchor)) {
      final double x =
          direction == FlipDirection.next ? -_vp.width * 0.18 : _vp.width * 1.18;
      final double inset = (_vp.height * 0.05).clamp(18, 42).toDouble();
      return Offset(
        x,
        anchor.dy.clamp(inset, _vp.height - inset).toDouble(),
      );
    }

    final bool top = anchor.dy <= _vp.height * 0.5;
    final double yOut = _vp.height * 0.10;
    return direction == FlipDirection.next
        ? Offset(-_vp.width * 0.18, top ? -yOut : _vp.height + yOut)
        : Offset(_vp.width * 1.18, top ? -yOut : _vp.height + yOut);
  }

  // ---- gestures -----------------------------------------------------------

  _DragIntent? _dragIntentFor(Offset position) {
    if (_vp.isEmpty) return null;
    final double edgeZone = _edgeZoneWidth();
    if (position.dx >= _vp.width - edgeZone && _canNext) {
      return _DragIntent(
        direction: FlipDirection.next,
        position: position,
        anchor: _edgeAnchorFor(FlipDirection.next, _edgeAnchorY(position.dy)),
      );
    }
    if (position.dx <= edgeZone && _canPrev) {
      return _DragIntent(
        direction: FlipDirection.prev,
        position: position,
        anchor: _edgeAnchorFor(FlipDirection.prev, _edgeAnchorY(position.dy)),
      );
    }
    return null;
  }

  void _beginDrag(_DragIntent intent, {Offset? currentPosition}) {
    _ac.stop();
    _animToken++;
    final Offset start = clampPointToPage(
      currentPosition ?? intent.position,
      _vp,
      overscrollX: _dragOverscrollX,
      overscrollY: _dragOverscrollY,
    );
    final Offset seed = clampPointToPage(
      intent.position,
      _vp,
      overscrollX: _dragOverscrollX,
      overscrollY: _dragOverscrollY,
    );
    final Offset c = intent.anchor;
    final int now = nowMicros();
    _vel.reset();
    _vel.addSample(seed, now - const Duration(milliseconds: 16).inMicroseconds);
    _vel.addSample(start, now);
    setState(() {
      _dir = intent.direction;
      _corner = c;
      _drag = start;
      _state = _Flip.dragging;
    });
  }

  void _onPanDown(DragDownDetails det) {
    if (_isAnimating || _imgs.isEmpty || _rasterizing) {
      _pendingDrag = null;
      return;
    }
    _pendingDrag = _dragIntentFor(det.localPosition);
  }

  void _onPanStart(DragStartDetails det) {
    if (_isAnimating || _imgs.isEmpty || _rasterizing) return;
    final _DragIntent? intent = _pendingDrag ?? _dragIntentFor(det.localPosition);
    _pendingDrag = null;
    if (intent == null) return;
    _beginDrag(intent, currentPosition: det.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails det) {
    if (_state != _Flip.dragging || _dir == null) return;
    final Offset c = clampPointToPage(
      det.localPosition,
      _vp,
      overscrollX: _dragOverscrollX,
      overscrollY: _dragOverscrollY,
    );
    _vel.addSample(c, nowMicros());
    setState(() => _drag = c);
  }

  void _onPanEnd(DragEndDetails det) {
    if (_state != _Flip.dragging ||
        _dir == null ||
        _corner == null ||
        _drag == null) return;

    _pendingDrag = null;
    final Offset v = Offset.lerp(
          _vel.estimateVelocity(),
          det.velocity.pixelsPerSecond,
          0.55,
        ) ??
        det.velocity.pixelsPerSecond;
    final CurlGeometry g = computeCurlGeometry(
      size: _vp,
      dragPoint: _drag!,
      corner: _corner!,
      direction: _dir!,
      curlRadius: _curlR,
    );
    final InertiaDecision dec = decideInertia(
      progress: g.progress,
      velocityX: v.dx,
      direction: _dir!,
      commitThreshold: _cfg.commitThreshold,
    );
    if (dec.commit) {
      _animateCommit(dec.duration);
    } else {
      _animateBack(dec.directionalVelocity);
    }
  }

  void _onPanCancel() {
    _pendingDrag = null;
    if (_state == _Flip.dragging) _animateBack(0);
  }

  void _onTapUp(TapUpDetails det) {
    if (_isAnimating || _state != _Flip.idle || _imgs.isEmpty) return;
    _pendingDrag = null;
    final Offset p = det.localPosition;
    final double tapZone = _tapZoneWidth();
    if (p.dx >= _vp.width - tapZone && _canNext) {
      _startTapFlip(
        _DragIntent(
          direction: FlipDirection.next,
          position: p,
          anchor: _edgeAnchorFor(FlipDirection.next, _edgeAnchorY(p.dy)),
        ),
      );
    } else if (p.dx <= tapZone && _canPrev) {
      _startTapFlip(
        _DragIntent(
          direction: FlipDirection.prev,
          position: p,
          anchor: _edgeAnchorFor(FlipDirection.prev, _edgeAnchorY(p.dy)),
        ),
      );
    }
  }

  // ---- flip animations ----------------------------------------------------

  void _startTapFlip(_DragIntent intent) {
    final Offset c = intent.anchor;
    final bool side = _isSideAnchor(c);
    final bool top = c.dy < _vp.height * 0.5;
    final Offset start = intent.direction == FlipDirection.next
        ? c + Offset(-18, side ? 0 : (top ? 12 : -12))
        : c + Offset(18, side ? 0 : (top ? 12 : -12));
    final Offset end = _commitTargetFor(
      direction: intent.direction,
      anchor: c,
    );

    setState(() {
      _dir = intent.direction;
      _corner = c;
      _drag = start;
      _state =
          intent.direction == FlipDirection.next ? _Flip.toNext : _Flip.toPrev;
    });

    _startTimed(
      from: start,
      to: end,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _animateCommit(Duration dur) {
    if (_dir == null || _corner == null || _drag == null) return;
    final Offset target = _commitTargetFor(
      direction: _dir!,
      anchor: _corner!,
    );

    setState(() {
      _state = _dir == FlipDirection.next ? _Flip.toNext : _Flip.toPrev;
    });

    _startTimed(
      from: _drag!,
      to: target,
      duration: dur,
      curve: Curves.easeOutCubic,
    );
  }

  void _animateBack(double dirVel) {
    if (_corner == null || _drag == null || _dir == null) return;
    setState(() => _state = _Flip.back);
    final double nv =
        (-dirVel / math.max(1, _vp.width)).clamp(-4.5, 4.5);
    final SpringSimulation sim = buildBackSimulation(
      spring: _cfg.spring,
      damping: _cfg.damping,
      normalizedVelocity: nv,
    );
    _startSpring(from: _drag!, to: _corner!, simulation: sim);
  }

  Future<void> _startTimed({
    required Offset from,
    required Offset to,
    required Duration duration,
    required Curve curve,
  }) async {
    final int tk = ++_animToken;
    _ac.stop();
    _animFrom = from;
    _animTo = to;
    _ac.value = 0;
    await _ac.animateTo(1, duration: duration, curve: curve);
    if (!mounted || tk != _animToken) return;
    _handleDone();
  }

  Future<void> _startSpring({
    required Offset from,
    required Offset to,
    required SpringSimulation simulation,
  }) async {
    final int tk = ++_animToken;
    _ac.stop();
    _animFrom = from;
    _animTo = to;
    _ac.value = 0;
    await _ac.animateWith(simulation);
    if (!mounted || tk != _animToken) return;
    _handleDone();
  }

  void _handleDone() {
    final int prev = _page;
    setState(() {
      if (_state == _Flip.toNext && _canNext) _page += 1;
      if (_state == _Flip.toPrev && _canPrev) _page -= 1;
      _resetFlip(keepPage: true);
    });
    if (_page != prev) widget.onPageChanged?.call(_page);
  }

  void _resetFlip({required bool keepPage}) {
    _state = _Flip.idle;
    _dir = null;
    _corner = null;
    _drag = null;
    _animFrom = null;
    _animTo = null;
    _pendingDrag = null;
    _vel.reset();
    if (!keepPage) _page = 0;
  }

  // ---- geometry helpers ---------------------------------------------------

  CurlGeometry? _buildGeometry() {
    if (_state == _Flip.idle ||
        _dir == null ||
        _corner == null ||
        _drag == null ||
        _vp.isEmpty) return null;

    final bool overshoot =
        _state == _Flip.toNext ||
        _state == _Flip.toPrev ||
        _state == _Flip.dragging;
    return computeCurlGeometry(
      size: _vp,
      dragPoint: _drag!,
      corner: _corner!,
      direction: _dir!,
      curlRadius: _curlR,
      overscrollX: overshoot ? math.max(_dragOverscrollX, _vp.width * 0.42) : 0,
      overscrollY:
          overshoot ? math.max(_dragOverscrollY, _vp.height * 0.20) : 0,
    );
  }

  ui.Image? _belowImage() {
    if (_dir == null || _imgs.isEmpty) return null;
    final int idx = _dir == FlipDirection.next ? _page + 1 : _page - 1;
    if (idx < 0 || idx >= _imgs.length) return null;
    return _imgs[idx];
  }

  Size _fitPage(Size avail) {
    final double ratio = _cfg.pageRatio;
    final double sw = math.max(260, avail.width - 24);
    final double sh = math.max(360, avail.height - 16);
    double w = sw.clamp(260.0, 620.0);
    double h = w / ratio;
    if (h > sh) {
      h = sh;
      w = h * ratio;
    }
    return Size(w, h);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final Size pageSize =
            _fitPage(Size(constraints.maxWidth, constraints.maxHeight));
        _onViewportChanged(pageSize);

        final bool ready = !_rasterizing &&
            _imgs.isNotEmpty &&
            _imgs.length == _pages.length &&
            _sameSize(_rasterizedSize, pageSize);

        final CurlGeometry? geom = ready ? _buildGeometry() : null;
        final ui.Image? below = ready ? _belowImage() : null;

        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: <BoxShadow>[
                BoxShadow(
                  blurRadius: 28,
                  spreadRadius: 2,
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SizedBox(
              width: pageSize.width,
              height: pageSize.height,
              child: ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: _onPanDown,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                  onTapUp: _onTapUp,
                  child: ready
                      ? RepaintBoundary(
                          child: CustomPaint(
                            size: pageSize,
                            painter: PageCurlPainter(
                              currentImage: _imgs[_page],
                              belowImage: below,
                              backFaceImage: _imgs[_page],
                              geometry: geom,
                              shadowStrength: _cfg.shadowStrength,
                              shadowWidth: _cfg.shadowWidth,
                              highlightStrength: _cfg.highlightStrength,
                              backFaceTint: _cfg.theme.effectiveBackFaceTint,
                            ),
                          ),
                        )
                      : Container(
                          color: _cfg.theme.pageColor,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
