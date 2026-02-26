import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'geometry.dart';
import 'page_curl_painter.dart';
import 'pages.dart';
import 'physics.dart';

enum ViewerState {
  idle,
  dragging,
  animatingToNext,
  animatingBack,
  animatingToPrev,
}

class PageViewer extends StatefulWidget {
  const PageViewer({super.key});

  @override
  State<PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<PageViewer>
    with SingleTickerProviderStateMixin {
  static const double _edgeZoneWidth = 62;

  late final AnimationController _animationController;
  final PointerVelocityEstimator _velocityEstimator = PointerVelocityEstimator();

  ViewerState _state = ViewerState.idle;
  FlipDirection? _direction;

  int _currentPageIndex = 0;
  Size _viewportSize = Size.zero;

  List<ui.Image> _pageImages = <ui.Image>[];
  bool _isRasterizing = false;
  int _rasterTaskToken = 0;
  Size _rasterizedSize = Size.zero;
  Size _requestedRasterSize = Size.zero;

  Offset? _dragPoint;
  Offset? _activeCorner;
  Offset? _animFrom;
  Offset? _animTo;
  int _animationToken = 0;

  bool _showTuningPanel = true;

  double _shadowStrength = 0.90;
  double _shadowWidth = 44;
  double _highlightStrength = 0.70;
  double _spring = 420;
  double _damping = 24;
  double _commitThreshold = 0.44;
  double _curlRadiusFactor = 1.18;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      lowerBound: -0.5,
      upperBound: 1.5,
    )..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _animationController.dispose();
    disposePageImages(_pageImages);
    super.dispose();
  }

  bool get _canFlipNext => _currentPageIndex < kDemoPages.length - 1;

  bool get _canFlipPrev => _currentPageIndex > 0;

  bool get _isAnimating =>
      _state == ViewerState.animatingBack ||
      _state == ViewerState.animatingToNext ||
      _state == ViewerState.animatingToPrev;

  bool _isSameSize(Size a, Size b, [double tolerance = 0.5]) {
    return (a.width - b.width).abs() <= tolerance &&
        (a.height - b.height).abs() <= tolerance;
  }

  double get _curlRadiusPx {
    if (_viewportSize.width <= 0) {
      return 1;
    }
    return _viewportSize.width * _curlRadiusFactor;
  }

  void _onAnimationTick() {
    if (_animFrom == null || _animTo == null) {
      return;
    }

    final double t = _animationController.value.clamp(0.0, 1.0);
    setState(() {
      _dragPoint = Offset.lerp(_animFrom, _animTo, t);
    });
  }

  Future<void> _ensureRasterized(Size size) async {
    if (size.width <= 1 || size.height <= 1) {
      return;
    }

    final bool sameAsRequested = _isSameSize(_requestedRasterSize, size);
    final bool sameAsRasterized =
        _isSameSize(_rasterizedSize, size) && _pageImages.isNotEmpty;

    if (sameAsRequested && (_isRasterizing || sameAsRasterized)) {
      return;
    }

    _requestedRasterSize = size;
    final int token = ++_rasterTaskToken;
    if (mounted) {
      setState(() {
        _isRasterizing = true;
      });
    }

    final List<ui.Image> images = <ui.Image>[];
    for (final DemoPageData page in kDemoPages) {
      images.add(
        await rasterizePageImage(
          size: size,
          page: page,
          typography: kPaperTypography,
        ),
      );
    }

    if (!mounted || token != _rasterTaskToken) {
      disposePageImages(images);
      return;
    }

    disposePageImages(_pageImages);

    setState(() {
      _pageImages = images;
      _rasterizedSize = size;
      _isRasterizing = false;

      if (_currentPageIndex >= _pageImages.length) {
        _currentPageIndex = math.max(0, _pageImages.length - 1);
      }
      _resetFlipState(keepPageIndex: true);
    });
  }

  void _onViewportChanged(Size newSize) {
    if (_isSameSize(_viewportSize, newSize)) {
      return;
    }
    _viewportSize = newSize;
    Future<void>.microtask(() => _ensureRasterized(newSize));
  }

  Offset _cornerForDirection(FlipDirection direction, {required bool useTop}) {
    final double x = direction == FlipDirection.next ? _viewportSize.width : 0;
    final double y = useTop ? 0 : _viewportSize.height;
    return Offset(x, y);
  }

  void _beginDrag(FlipDirection direction, Offset localPosition) {
    _animationController.stop();
    _animationToken++;

    final bool useTopCorner = localPosition.dy < _viewportSize.height * 0.5;
    final Offset corner =
        _cornerForDirection(direction, useTop: useTopCorner);

    _velocityEstimator.reset();
    _velocityEstimator.addSample(localPosition, nowMicros());

    setState(() {
      _direction = direction;
      _activeCorner = corner;
      _dragPoint = clampPointToPage(localPosition, _viewportSize);
      _state = ViewerState.dragging;
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating || _pageImages.isEmpty || _isRasterizing) {
      return;
    }

    final Offset localPosition = details.localPosition;
    final bool inRightEdge = localPosition.dx >= _viewportSize.width - _edgeZoneWidth;
    final bool inLeftEdge = localPosition.dx <= _edgeZoneWidth;

    if (inRightEdge && _canFlipNext) {
      _beginDrag(FlipDirection.next, localPosition);
      return;
    }

    if (inLeftEdge && _canFlipPrev) {
      _beginDrag(FlipDirection.prev, localPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_state != ViewerState.dragging || _direction == null) {
      return;
    }

    final Offset clamped = clampPointToPage(details.localPosition, _viewportSize);
    _velocityEstimator.addSample(clamped, nowMicros());

    setState(() {
      _dragPoint = clamped;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_state != ViewerState.dragging ||
        _direction == null ||
        _activeCorner == null ||
        _dragPoint == null) {
      return;
    }

    final Offset velocity = _velocityEstimator.estimateVelocity();
    final CurlGeometry geometry = computeCurlGeometry(
      size: _viewportSize,
      dragPoint: _dragPoint!,
      corner: _activeCorner!,
      direction: _direction!,
      curlRadius: _curlRadiusPx,
    );

    final InertiaDecision decision = decideInertia(
      progress: geometry.progress,
      velocityX: velocity.dx,
      direction: _direction!,
      commitThreshold: _commitThreshold,
    );

    if (decision.commit) {
      _animateToCommit(decision.duration);
    } else {
      _animateBack(decision.directionalVelocity);
    }
  }

  void _onPanCancel() {
    if (_state == ViewerState.dragging) {
      _animateBack(0);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isAnimating || _state != ViewerState.idle || _pageImages.isEmpty) {
      return;
    }

    final Offset p = details.localPosition;
    final double rightZone = _viewportSize.width * 0.8;
    final double leftZone = _viewportSize.width * 0.2;

    if (p.dx >= rightZone && _canFlipNext) {
      _startTapFlip(FlipDirection.next, p.dy);
      return;
    }

    if (p.dx <= leftZone && _canFlipPrev) {
      _startTapFlip(FlipDirection.prev, p.dy);
    }
  }

  void _startTapFlip(FlipDirection direction, double tapY) {
    final bool useTopCorner = tapY < _viewportSize.height * 0.5;
    final Offset corner =
        _cornerForDirection(direction, useTop: useTopCorner);

    final Offset start = direction == FlipDirection.next
        ? corner + Offset(-18, useTopCorner ? 12 : -12)
        : corner + Offset(18, useTopCorner ? 12 : -12);

    final double yOut = _viewportSize.height * 0.18;
    final Offset end = direction == FlipDirection.next
        ? Offset(-_viewportSize.width * 0.36, useTopCorner ? -yOut : _viewportSize.height + yOut)
        : Offset(_viewportSize.width * 1.36, useTopCorner ? -yOut : _viewportSize.height + yOut);

    setState(() {
      _direction = direction;
      _activeCorner = corner;
      _dragPoint = start;
      _state = direction == FlipDirection.next
          ? ViewerState.animatingToNext
          : ViewerState.animatingToPrev;
    });

    _startTimedAnimation(
      from: start,
      to: end,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _animateToCommit(Duration duration) {
    if (_direction == null || _activeCorner == null || _dragPoint == null) {
      return;
    }

    final bool useTopCorner = _activeCorner!.dy <= _viewportSize.height * 0.5;
    final double yOut = _viewportSize.height * 0.18;

    final Offset target = _direction == FlipDirection.next
        ? Offset(-_viewportSize.width * 0.36, useTopCorner ? -yOut : _viewportSize.height + yOut)
        : Offset(_viewportSize.width * 1.36, useTopCorner ? -yOut : _viewportSize.height + yOut);

    setState(() {
      _state = _direction == FlipDirection.next
          ? ViewerState.animatingToNext
          : ViewerState.animatingToPrev;
    });

    _startTimedAnimation(
      from: _dragPoint!,
      to: target,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  void _animateBack(double directionalVelocity) {
    if (_activeCorner == null || _dragPoint == null || _direction == null) {
      return;
    }

    setState(() {
      _state = ViewerState.animatingBack;
    });

    final double normalizedVelocity =
        (-directionalVelocity / math.max(1, _viewportSize.width)).clamp(-4.5, 4.5);

    final SpringSimulation simulation = buildBackSimulation(
      spring: _spring,
      damping: _damping,
      normalizedVelocity: normalizedVelocity,
    );

    _startSpringAnimation(
      from: _dragPoint!,
      to: _activeCorner!,
      simulation: simulation,
    );
  }

  Future<void> _startTimedAnimation({
    required Offset from,
    required Offset to,
    required Duration duration,
    required Curve curve,
  }) async {
    final int token = ++_animationToken;
    _animationController.stop();
    _animFrom = from;
    _animTo = to;
    _animationController.value = 0;

    await _animationController.animateTo(
      1,
      duration: duration,
      curve: curve,
    );

    if (!mounted || token != _animationToken) {
      return;
    }
    _handleAnimationCompletion();
  }

  Future<void> _startSpringAnimation({
    required Offset from,
    required Offset to,
    required SpringSimulation simulation,
  }) async {
    final int token = ++_animationToken;
    _animationController.stop();
    _animFrom = from;
    _animTo = to;
    _animationController.value = 0;

    await _animationController.animateWith(simulation);

    if (!mounted || token != _animationToken) {
      return;
    }
    _handleAnimationCompletion();
  }

  void _handleAnimationCompletion() {
    setState(() {
      switch (_state) {
        case ViewerState.animatingToNext:
          if (_canFlipNext) {
            _currentPageIndex += 1;
          }
          break;
        case ViewerState.animatingToPrev:
          if (_canFlipPrev) {
            _currentPageIndex -= 1;
          }
          break;
        case ViewerState.animatingBack:
        case ViewerState.dragging:
        case ViewerState.idle:
          break;
      }

      _resetFlipState(keepPageIndex: true);
    });
  }

  void _resetFlipState({required bool keepPageIndex}) {
    _state = ViewerState.idle;
    _direction = null;
    _activeCorner = null;
    _dragPoint = null;
    _animFrom = null;
    _animTo = null;
    _velocityEstimator.reset();

    if (!keepPageIndex) {
      _currentPageIndex = 0;
    }
  }

  CurlGeometry? _buildGeometry() {
    if (_state == ViewerState.idle ||
        _direction == null ||
        _activeCorner == null ||
        _dragPoint == null ||
        _viewportSize.isEmpty) {
      return null;
    }

    final bool allowOverscroll =
        _state == ViewerState.animatingToNext ||
        _state == ViewerState.animatingToPrev;

    return computeCurlGeometry(
      size: _viewportSize,
      dragPoint: _dragPoint!,
      corner: _activeCorner!,
      direction: _direction!,
      curlRadius: _curlRadiusPx,
      overscrollX: allowOverscroll ? _viewportSize.width * 0.42 : 0,
      overscrollY: allowOverscroll ? _viewportSize.height * 0.20 : 0,
    );
  }

  ui.Image? _resolveBelowImage() {
    if (_direction == null || _pageImages.isEmpty) {
      return null;
    }

    final int targetIndex =
        _direction == FlipDirection.next ? _currentPageIndex + 1 : _currentPageIndex - 1;

    if (targetIndex < 0 || targetIndex >= _pageImages.length) {
      return null;
    }
    return _pageImages[targetIndex];
  }

  Size _fitPageSize(Size available) {
    const double ratio = 0.70;
    final double safeWidth = math.max(260, available.width - 24);
    final double safeHeight = math.max(360, available.height - 16);

    double width = safeWidth.clamp(260, 620);
    double height = width / ratio;

    if (height > safeHeight) {
      height = safeHeight;
      width = height * ratio;
    }

    return Size(width, height);
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String Function(double value)? formatter,
  }) {
    final String shownValue = formatter?.call(value) ?? value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(shownValue, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTuningPanel(CurlGeometry? geometry) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF201A15),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Page ${_currentPageIndex + 1}/${kDemoPages.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 14),
              Text(
                'State: ${_state.name}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              if (geometry != null)
                Text(
                  'progress ${geometry.progress.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(width: 8),
              Switch(
                value: _showTuningPanel,
                onChanged: (bool v) {
                  setState(() {
                    _showTuningPanel = v;
                  });
                },
              ),
            ],
          ),
          if (_showTuningPanel)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 290),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      _buildSlider(
                        label: 'shadowStrength',
                        value: _shadowStrength,
                        min: 0.0,
                        max: 1.8,
                        onChanged: (double v) => setState(() => _shadowStrength = v),
                      ),
                      _buildSlider(
                        label: 'shadowWidth',
                        value: _shadowWidth,
                        min: 10,
                        max: 120,
                        formatter: (double v) => v.toStringAsFixed(0),
                        onChanged: (double v) => setState(() => _shadowWidth = v),
                      ),
                      _buildSlider(
                        label: 'highlightStrength',
                        value: _highlightStrength,
                        min: 0.0,
                        max: 1.6,
                        onChanged: (double v) => setState(() => _highlightStrength = v),
                      ),
                      _buildSlider(
                        label: 'spring',
                        value: _spring,
                        min: 120,
                        max: 900,
                        formatter: (double v) => v.toStringAsFixed(0),
                        onChanged: (double v) => setState(() => _spring = v),
                      ),
                      _buildSlider(
                        label: 'damping',
                        value: _damping,
                        min: 8,
                        max: 48,
                        formatter: (double v) => v.toStringAsFixed(1),
                        onChanged: (double v) => setState(() => _damping = v),
                      ),
                      _buildSlider(
                        label: 'commitThreshold',
                        value: _commitThreshold,
                        min: 0.20,
                        max: 0.85,
                        onChanged: (double v) => setState(() => _commitThreshold = v),
                      ),
                      _buildSlider(
                        label: 'curlRadius',
                        value: _curlRadiusFactor,
                        min: 0.55,
                        max: 1.85,
                        formatter: (double v) => '${v.toStringAsFixed(2)}x',
                        onChanged: (double v) => setState(() => _curlRadiusFactor = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17120F),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size panelAware = Size(
              constraints.maxWidth,
              constraints.maxHeight - (_showTuningPanel ? 320 : 84),
            );
            final Size pageSize = _fitPageSize(panelAware);
            _onViewportChanged(pageSize);

            final bool ready =
                !_isRasterizing &&
                _pageImages.length == kDemoPages.length &&
                _isSameSize(_rasterizedSize, pageSize);

            final CurlGeometry? geometry = ready ? _buildGeometry() : null;
            final ui.Image? belowImage = ready ? _resolveBelowImage() : null;

            return Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            blurRadius: 28,
                            spreadRadius: 2,
                            color: Colors.black.withOpacity(0.35),
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
                                        currentImage: _pageImages[_currentPageIndex],
                                        belowImage: belowImage,
                                        backFaceImage: belowImage,
                                        geometry: geometry,
                                        shadowStrength: _shadowStrength,
                                        shadowWidth: _shadowWidth,
                                        highlightStrength: _highlightStrength,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFFF4EAD8),
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(strokeWidth: 2),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildTuningPanel(geometry),
              ],
            );
          },
        ),
      ),
    );
  }
}
