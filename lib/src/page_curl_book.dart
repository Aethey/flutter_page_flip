import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import 'document.dart';
import 'geometry.dart';
import 'page_content_view.dart';
import 'page_curl_config.dart';
import 'page_curl_painter.dart';
import 'pagination.dart';
import 'pages.dart';
import 'physics.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

typedef PageCurlPageBuilder = FutureOr<BookPage> Function(int pageIndex);

enum _PageCurlNavigationKind { next, previous, jump }

class _PageCurlNavigationCommand {
  const _PageCurlNavigationCommand({
    required this.kind,
    required this.animated,
    this.targetPage,
  });

  final _PageCurlNavigationKind kind;
  final bool animated;
  final int? targetPage;
}

class PageCurlController extends ChangeNotifier {
  PageCurlController({
    List<BookPage> pages = const <BookPage>[],
    BookDocument? document,
    int? pageCount,
    PageCurlPageBuilder? pageBuilder,
    PageCurlConfig config = const PageCurlConfig(),
  }) : _pages = List.of(pages),
       _document = document,
       _pageCount = pageCount,
       _pageBuilder = pageBuilder,
       _config = config;

  PageCurlController.document({
    required BookDocument document,
    PageCurlConfig config = const PageCurlConfig(),
  }) : this(document: document, config: config);

  PageCurlController.builder({
    required int pageCount,
    required PageCurlPageBuilder pageBuilder,
    PageCurlConfig config = const PageCurlConfig(),
  }) : this(pageCount: pageCount, pageBuilder: pageBuilder, config: config);

  List<BookPage> _pages;
  BookDocument? _document;
  int? _pageCount;
  PageCurlPageBuilder? _pageBuilder;
  PageCurlConfig _config;
  int _resolvedPageCount = 0;
  int _navigationCommandVersion = 0;
  _PageCurlNavigationCommand? _pendingNavigationCommand;

  List<BookPage> get pages => _pages;
  BookDocument? get document => _document;
  int? get pageCount => _pageCount;
  PageCurlPageBuilder? get pageBuilder => _pageBuilder;
  PageCurlConfig get config => _config;
  int get totalPages => switch ((_document != null, _pageBuilder != null)) {
    (true, _) => _resolvedPageCount,
    (false, true) => _pageCount ?? 0,
    _ => _pages.length,
  };
  bool get usesBuilder => _pageBuilder != null;
  int get navigationCommandVersion => _navigationCommandVersion;
  _PageCurlNavigationCommand? get pendingNavigationCommand =>
      _pendingNavigationCommand;

  set config(PageCurlConfig value) {
    _config = value;
    notifyListeners();
  }

  set document(BookDocument? value) {
    _document = value;
    _pageBuilder = null;
    _pageCount = null;
    _resolvedPageCount = 0;
    notifyListeners();
  }

  set pages(List<BookPage> value) {
    _pages = List.of(value);
    if (_document != null) {
      _document = null;
    }
    _pageBuilder = null;
    _pageCount = null;
    _resolvedPageCount = 0;
    notifyListeners();
  }

  void setBuilder({
    required int pageCount,
    required PageCurlPageBuilder pageBuilder,
  }) {
    _document = null;
    _pages = const <BookPage>[];
    _pageCount = pageCount;
    _pageBuilder = pageBuilder;
    _resolvedPageCount = 0;
    notifyListeners();
  }

  void _updateResolvedPageCount(int value) {
    if (_resolvedPageCount == value) {
      return;
    }
    _resolvedPageCount = value;
    notifyListeners();
  }

  void nextPage({bool animated = true}) {
    _queueNavigation(
      const _PageCurlNavigationCommand(
        kind: _PageCurlNavigationKind.next,
        animated: true,
      ),
      animated: animated,
    );
  }

  void previousPage({bool animated = true}) {
    _queueNavigation(
      const _PageCurlNavigationCommand(
        kind: _PageCurlNavigationKind.previous,
        animated: true,
      ),
      animated: animated,
    );
  }

  void jumpToPage(int pageIndex) {
    _queueNavigation(
      _PageCurlNavigationCommand(
        kind: _PageCurlNavigationKind.jump,
        targetPage: pageIndex,
        animated: false,
      ),
      animated: false,
    );
  }

  void animateToPage(int pageIndex) {
    _queueNavigation(
      _PageCurlNavigationCommand(
        kind: _PageCurlNavigationKind.jump,
        targetPage: pageIndex,
        animated: true,
      ),
      animated: true,
    );
  }

  void _queueNavigation(
    _PageCurlNavigationCommand command, {
    required bool animated,
  }) {
    _pendingNavigationCommand = _PageCurlNavigationCommand(
      kind: command.kind,
      targetPage: command.targetPage,
      animated: animated,
    );
    _navigationCommandVersion++;
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
  int? _pendingInitialPage;
  Size _vp = Size.zero;

  List<BookPage>? _autoPages;
  bool _paginating = false;
  int _paginationToken = 0;
  Size _paginatedSize = Size.zero;
  Size _requestedPaginationSize = Size.zero;
  final Map<int, BookPage> _pageCache = <int, BookPage>{};
  final Map<int, ui.Image> _imageCache = <int, ui.Image>{};
  final GlobalKey _livePageBoundaryKey = GlobalKey();
  final Set<int> _loadingPages = <int>{};
  final Set<int> _rasterizingPages = <int>{};
  int _contentEpoch = 0;
  Size _imageCacheSize = Size.zero;
  ui.Image? _visiblePageSnapshot;
  int _visibleSnapshotPage = -1;
  Size _visibleSnapshotSize = Size.zero;
  int _visibleSnapshotToken = 0;
  bool _snapshotCaptureScheduled = false;

  Offset? _drag;
  Offset? _corner;
  Offset? _animFrom;
  Offset? _animTo;
  _DragIntent? _pendingDrag;
  bool _ignoreControllerChange = false;
  int _handledNavigationCommandVersion = 0;
  int _animToken = 0;

  PageCurlConfig get _cfg => widget.controller.config;
  BookDocument? get _document => widget.controller.document;
  bool get _usesBuilder => widget.controller.usesBuilder;
  List<BookPage> get _pages =>
      _document != null
          ? (_autoPages ?? const <BookPage>[])
          : widget.controller.pages;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final int totalPages = widget.controller.totalPages;
    if (totalPages > 0) {
      _page = widget.initialPage.clamp(0, totalPages - 1);
    } else {
      _page = 0;
      _pendingInitialPage = widget.initialPage;
    }
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
    disposePageImages(_imageCache.values);
    _disposeVisibleSnapshot();
    super.dispose();
  }

  // ---- controller sync ----------------------------------------------------

  void _onControllerChanged() {
    if (_ignoreControllerChange) {
      _ignoreControllerChange = false;
      return;
    }

    if (_handledNavigationCommandVersion !=
        widget.controller.navigationCommandVersion) {
      _handledNavigationCommandVersion =
          widget.controller.navigationCommandVersion;
      final _PageCurlNavigationCommand? command =
          widget.controller.pendingNavigationCommand;
      if (command != null) {
        Future<void>.microtask(() => _handleControllerNavigation(command));
      }
      return;
    }

    setState(() {
      final int total = widget.controller.totalPages;
      if (_pendingInitialPage != null && total > 0) {
        _page = _pendingInitialPage!.clamp(0, total - 1);
        _pendingInitialPage = null;
      } else if (_page >= total) {
        _page = math.max(0, total - 1);
      }
    });
    _contentEpoch++;
    _clearImageCache();
    _invalidateVisibleSnapshot();
    if (_document != null) {
      _paginatedSize = Size.zero;
      _requestedPaginationSize = Size.zero;
      _autoPages = null;
      _pageCache.clear();
      widget.controller._updateResolvedPageCount(0);
    } else if (!_usesBuilder) {
      _pageCache.clear();
      for (int i = 0; i < _pages.length; i++) {
        _pageCache[i] = _pages[i];
      }
    } else {
      _pageCache.clear();
    }
    if (_vp.width > 1 && _vp.height > 1) {
      Future<void>.microtask(() => _resolveContentForViewport(_vp));
    }
  }

  // ---- helpers ------------------------------------------------------------

  bool get _canNext => _page < widget.controller.totalPages - 1;
  bool get _canPrev => _page > 0;

  bool get _isAnimating =>
      _state == _Flip.back || _state == _Flip.toNext || _state == _Flip.toPrev;

  BookPage? get _currentPageData => _pageCache[_page] ?? _syncPageAt(_page);

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

  BookPage? _syncPageAt(int index) {
    if (index < 0 || index >= widget.controller.totalPages) {
      return null;
    }

    if (_pageCache.containsKey(index)) {
      return _pageCache[index];
    }

    if (_document != null) {
      if (_autoPages == null || index >= _autoPages!.length) {
        return null;
      }
      final BookPage page = _autoPages![index];
      _pageCache[index] = page;
      return page;
    }

    if (_usesBuilder) {
      return null;
    }

    if (index >= _pages.length) {
      return null;
    }
    final BookPage page = _pages[index];
    _pageCache[index] = page;
    return page;
  }

  ui.Image? _imageAt(int index) => _imageCache[index];

  int? _targetPageIndex([FlipDirection? direction]) {
    final FlipDirection? effectiveDirection = direction ?? _dir;
    if (effectiveDirection == null) {
      return null;
    }
    return effectiveDirection == FlipDirection.next ? _page + 1 : _page - 1;
  }

  BookPage? _targetPageData([FlipDirection? direction]) {
    final int? index = _targetPageIndex(direction);
    if (index == null) {
      return null;
    }
    return _syncPageAt(index);
  }

  bool get _hasFreshVisibleSnapshot =>
      _visiblePageSnapshot != null &&
      _visibleSnapshotPage == _page &&
      _sameSize(_visibleSnapshotSize, _vp);

  ui.Image? get _currentAnimationImage =>
      _hasFreshVisibleSnapshot ? _visiblePageSnapshot : _imageAt(_page);

  List<int> _indicesToWarm(int center) {
    final int total = widget.controller.totalPages;
    final Set<int> indices = <int>{center - 1, center, center + 1};
    if (_dir == FlipDirection.next || _state == _Flip.toNext) {
      indices.add(center + 2);
    } else if (_dir == FlipDirection.prev || _state == _Flip.toPrev) {
      indices.add(center - 2);
    }
    return indices.where((int i) => i >= 0 && i < total).toList()..sort();
  }

  bool _hasResourcesForDirection(FlipDirection direction) {
    final int? belowIndex = _targetPageIndex(direction);
    if (belowIndex == null) {
      return false;
    }
    final bool hasTarget =
        _targetPageData(direction) != null || _imageAt(belowIndex) != null;
    return _currentAnimationImage != null && hasTarget;
  }

  void _disposeVisibleSnapshot() {
    _visiblePageSnapshot?.dispose();
    _visiblePageSnapshot = null;
    _visibleSnapshotPage = -1;
    _visibleSnapshotSize = Size.zero;
  }

  void _invalidateVisibleSnapshot() {
    _visibleSnapshotToken++;
    _snapshotCaptureScheduled = false;
    _disposeVisibleSnapshot();
  }

  void _scheduleVisibleSnapshotCapture() {
    if (_snapshotCaptureScheduled ||
        !mounted ||
        _state != _Flip.idle ||
        _vp.isEmpty ||
        _currentPageData == null ||
        _hasFreshVisibleSnapshot) {
      return;
    }

    _snapshotCaptureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotCaptureScheduled = false;
      Future<void>.microtask(_captureVisibleSnapshot);
    });
  }

  Future<void> _captureVisibleSnapshot() async {
    if (!mounted ||
        _state != _Flip.idle ||
        _vp.isEmpty ||
        _currentPageData == null) {
      return;
    }

    final BuildContext? boundaryContext = _livePageBoundaryKey.currentContext;
    final RenderObject? renderObject = boundaryContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return;
    }

    if (!renderObject.attached) {
      _scheduleVisibleSnapshotCapture();
      return;
    }

    final int token = ++_visibleSnapshotToken;
    final int pageIndex = _page;
    final Size size = _vp;
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted ||
        token != _visibleSnapshotToken ||
        pageIndex != _page ||
        !_sameSize(size, _vp) ||
        _state != _Flip.idle ||
        !renderObject.attached) {
      return;
    }

    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: 1.0);
    } catch (_) {
      _scheduleVisibleSnapshotCapture();
      return;
    }

    if (!mounted ||
        token != _visibleSnapshotToken ||
        pageIndex != _page ||
        !_sameSize(size, _vp) ||
        _state != _Flip.idle) {
      image.dispose();
      return;
    }

    _visiblePageSnapshot?.dispose();
    _visiblePageSnapshot = image;
    _visibleSnapshotPage = pageIndex;
    _visibleSnapshotSize = size;
  }

  // ---- animation tick -----------------------------------------------------

  void _onAnimTick() {
    if (_animFrom == null || _animTo == null) return;
    final double t = _ac.value.clamp(0.0, 1.0);
    setState(() => _drag = Offset.lerp(_animFrom, _animTo, t));
  }

  // ---- rasterization ------------------------------------------------------

  Future<void> _resolveContentForViewport(Size size) async {
    if (_document != null) {
      await _ensurePaginated(size);
    }
    await _warmVisibleResources();
  }

  Future<void> _ensurePaginated(Size size) async {
    final BookDocument? document = _document;
    if (document == null || size.width <= 1 || size.height <= 1) {
      return;
    }

    final bool sameReq = _sameSize(_requestedPaginationSize, size);
    final bool sameResult =
        _sameSize(_paginatedSize, size) && _autoPages != null;
    if (sameReq && (_paginating || sameResult)) {
      return;
    }

    _requestedPaginationSize = size;
    final int token = ++_paginationToken;
    if (mounted) {
      setState(() => _paginating = true);
    }

    final List<BookPage> pages = await paginateBookDocument(
      document: document,
      size: size,
      typography: _cfg.typography,
    );

    if (!mounted || token != _paginationToken || _document != document) {
      return;
    }

    setState(() {
      _autoPages = pages;
      _paginatedSize = size;
      _paginating = false;
      if (_pendingInitialPage != null && pages.isNotEmpty) {
        _page = _pendingInitialPage!.clamp(0, pages.length - 1);
        _pendingInitialPage = null;
      } else if (_page >= pages.length) {
        _page = math.max(0, pages.length - 1);
      }
      _pageCache
        ..clear()
        ..addEntries(
          pages.asMap().entries.map(
            (MapEntry<int, BookPage> entry) =>
                MapEntry<int, BookPage>(entry.key, entry.value),
          ),
        );
      _resetFlip(keepPage: true);
    });
    _ignoreControllerChange = true;
    widget.controller._updateResolvedPageCount(pages.length);
  }

  Future<BookPage?> _ensurePageAvailable(int index) async {
    if (index < 0 || index >= widget.controller.totalPages) {
      return null;
    }

    final BookPage? sync = _syncPageAt(index);
    if (sync != null) {
      return sync;
    }

    if (!_usesBuilder || _loadingPages.contains(index)) {
      return _pageCache[index];
    }

    final PageCurlPageBuilder? builder = widget.controller.pageBuilder;
    if (builder == null) {
      return null;
    }

    final int epoch = _contentEpoch;
    _loadingPages.add(index);

    try {
      final BookPage page = await Future.sync(() => builder(index));
      if (!mounted || epoch != _contentEpoch) {
        return null;
      }
      if (mounted) {
        setState(() {
          _pageCache[index] = page;
        });
      } else {
        _pageCache[index] = page;
      }
      return page;
    } finally {
      _loadingPages.remove(index);
    }
  }

  Future<void> _warmVisibleResources() async {
    if (_vp.width <= 1 || _vp.height <= 1) {
      return;
    }

    final List<int> indices = _indicesToWarm(_page);
    await Future.wait(indices.map(_ensurePageAvailable));

    for (final int index in indices) {
      final BookPage? page = _pageCache[index];
      if (page == null) {
        continue;
      }
      await _ensureImageForPage(index, page);
    }

    _trimImageCache(indices.toSet());
  }

  Future<void> _ensureImageForPage(int index, BookPage page) async {
    if (_vp.width <= 1 || _vp.height <= 1) {
      return;
    }
    if (_imageCacheSize != _vp) {
      _clearImageCache();
      _imageCacheSize = _vp;
    }
    if (_imageCache.containsKey(index) || _rasterizingPages.contains(index)) {
      return;
    }

    final int epoch = _contentEpoch;
    _rasterizingPages.add(index);

    try {
      final ui.Image image = await rasterizePageImage(
        size: _vp,
        page: page,
        typography: _cfg.typography,
        theme: _cfg.theme,
      );

      if (!mounted ||
          epoch != _contentEpoch ||
          !_sameSize(_imageCacheSize, _vp)) {
        image.dispose();
        return;
      }

      setState(() {
        _imageCache.remove(index)?.dispose();
        _imageCache[index] = image;
      });
    } finally {
      _rasterizingPages.remove(index);
    }
  }

  void _trimImageCache(Set<int> keep) {
    final List<int> toRemove = _imageCache.keys
        .where((int index) => !keep.contains(index))
        .toList(growable: false);
    for (final int index in toRemove) {
      _imageCache.remove(index)?.dispose();
    }
  }

  void _clearImageCache() {
    disposePageImages(_imageCache.values);
    _imageCache.clear();
    _rasterizingPages.clear();
    _imageCacheSize = Size.zero;
  }

  // ---- viewport -----------------------------------------------------------

  void _onViewportChanged(Size s) {
    if (_sameSize(_vp, s)) return;
    _vp = s;
    _invalidateVisibleSnapshot();
    Future<void>.microtask(() => _resolveContentForViewport(s));
  }

  Offset _edgeAnchorFor(FlipDirection d, double y) {
    final double x = d == FlipDirection.next ? _vp.width : 0;
    return Offset(x, y.clamp(0, _vp.height).toDouble());
  }

  double _edgeAnchorY(double rawY) {
    final double y = rawY.clamp(0, _vp.height).toDouble();
    final double cornerBand = (_vp.height * 0.20).clamp(68, 150).toDouble();
    final double transitionBand = (_vp.height * 0.10).clamp(28, 72).toDouble();

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
      final double t = ((y - bottomTransitionStart) / transitionBand).clamp(
        0.0,
        1.0,
      );
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
          direction == FlipDirection.next
              ? -_vp.width * 0.18
              : _vp.width * 1.18;
      final double inset = (_vp.height * 0.05).clamp(18, 42).toDouble();
      return Offset(x, anchor.dy.clamp(inset, _vp.height - inset).toDouble());
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

  void _handlePanDown(Offset position) {
    if (_isAnimating || _currentPageData == null) {
      _pendingDrag = null;
      return;
    }
    if (!_hasFreshVisibleSnapshot) {
      _scheduleVisibleSnapshotCapture();
    }
    _pendingDrag = _dragIntentFor(position);
  }

  void _handlePanStart(Offset position) {
    if (_isAnimating || _currentPageData == null) return;
    final _DragIntent? intent = _pendingDrag ?? _dragIntentFor(position);
    _pendingDrag = null;
    if (intent == null) return;
    if (!_hasResourcesForDirection(intent.direction)) {
      Future<void>.microtask(_warmVisibleResources);
      return;
    }
    _beginDrag(intent, currentPosition: position);
  }

  void _handlePanUpdate(Offset position) {
    if (_state != _Flip.dragging || _dir == null) return;
    final Offset c = clampPointToPage(
      position,
      _vp,
      overscrollX: _dragOverscrollX,
      overscrollY: _dragOverscrollY,
    );
    _vel.addSample(c, nowMicros());
    setState(() => _drag = c);
  }

  void _handlePanEnd(Velocity velocity) {
    if (_state != _Flip.dragging ||
        _dir == null ||
        _corner == null ||
        _drag == null)
      return;

    _pendingDrag = null;
    final Offset v =
        Offset.lerp(_vel.estimateVelocity(), velocity.pixelsPerSecond, 0.55) ??
        velocity.pixelsPerSecond;
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

  void _handleTapUp(Offset position) {
    if (_isAnimating || _state != _Flip.idle || _currentPageData == null)
      return;
    _pendingDrag = null;
    final Offset p = position;
    final double tapZone = _tapZoneWidth();
    if (p.dx >= _vp.width - tapZone && _canNext) {
      if (!_hasResourcesForDirection(FlipDirection.next)) {
        Future<void>.microtask(_warmVisibleResources);
        return;
      }
      _startTapFlip(
        _DragIntent(
          direction: FlipDirection.next,
          position: p,
          anchor: _edgeAnchorFor(FlipDirection.next, _edgeAnchorY(p.dy)),
        ),
      );
    } else if (p.dx <= tapZone && _canPrev) {
      if (!_hasResourcesForDirection(FlipDirection.prev)) {
        Future<void>.microtask(_warmVisibleResources);
        return;
      }
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
    final Offset start =
        intent.direction == FlipDirection.next
            ? c + Offset(-18, side ? 0 : (top ? 12 : -12))
            : c + Offset(18, side ? 0 : (top ? 12 : -12));
    final Offset end = _commitTargetFor(direction: intent.direction, anchor: c);

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
    final Offset target = _commitTargetFor(direction: _dir!, anchor: _corner!);

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
    final double nv = (-dirVel / math.max(1, _vp.width)).clamp(-4.5, 4.5);
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

  Future<void> _handleControllerNavigation(
    _PageCurlNavigationCommand command,
  ) async {
    if (!mounted || _paginating || widget.controller.totalPages <= 0) {
      return;
    }
    if (_isAnimating || _state == _Flip.dragging) {
      return;
    }

    final int current = _page;
    final int target = switch (command.kind) {
      _PageCurlNavigationKind.next => math.min(
        widget.controller.totalPages - 1,
        current + 1,
      ),
      _PageCurlNavigationKind.previous => math.max(0, current - 1),
      _PageCurlNavigationKind.jump => (command.targetPage ?? current).clamp(
        0,
        math.max(0, widget.controller.totalPages - 1),
      ),
    };

    if (target == current) {
      return;
    }

    final bool adjacent = (target - current).abs() == 1;
    final FlipDirection? direction =
        target > current
            ? FlipDirection.next
            : target < current
            ? FlipDirection.prev
            : null;

    if (command.animated && adjacent && direction != null) {
      await _ensurePageAvailable(current);
      await _ensurePageAvailable(target);
      await _warmVisibleResources();
      if (!mounted || !_hasResourcesForDirection(direction)) {
        return;
      }
      final double y = _vp.height * 0.5;
      _startTapFlip(
        _DragIntent(
          direction: direction,
          position: Offset(direction == FlipDirection.next ? _vp.width : 0, y),
          anchor: _edgeAnchorFor(direction, _edgeAnchorY(y)),
        ),
      );
      return;
    }

    await _ensurePageAvailable(target);
    setState(() {
      _page = target;
      _resetFlip(keepPage: true);
    });
    widget.onPageChanged?.call(_page);
    _invalidateVisibleSnapshot();
    await _warmVisibleResources();
    _scheduleVisibleSnapshotCapture();
  }

  void _handleDone() {
    final int prev = _page;
    setState(() {
      if (_state == _Flip.toNext && _canNext) _page += 1;
      if (_state == _Flip.toPrev && _canPrev) _page -= 1;
      _resetFlip(keepPage: true);
    });
    if (_page != prev) widget.onPageChanged?.call(_page);
    _invalidateVisibleSnapshot();
    Future<void>.microtask(_warmVisibleResources);
    _scheduleVisibleSnapshotCapture();
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
        _vp.isEmpty)
      return null;

    // The release point can sit outside the page because dragging allows
    // overscroll. Keeping the same allowance while springing back avoids
    // re-clamping the touch into the page on the first frame of the return.
    final bool overshoot = _state != _Flip.idle;
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
    if (_dir == null) return null;
    final int idx = _dir == FlipDirection.next ? _page + 1 : _page - 1;
    return _imageAt(idx);
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

  Offset _zoneToPageOffset(
    Offset localPosition, {
    required FlipDirection direction,
    required double zoneWidth,
  }) {
    final double zoneLeft =
        direction == FlipDirection.prev ? 0 : _vp.width - zoneWidth;
    return Offset(zoneLeft + localPosition.dx, localPosition.dy);
  }

  Widget _buildPageBody(BookPage? page, {Key? boundaryKey}) {
    if (page == null) {
      return Container(
        color: _cfg.theme.pageColor,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return RepaintBoundary(
      key: boundaryKey,
      child: BookPageContentView(
        page: page,
        typography: _cfg.typography,
        theme: _cfg.theme,
      ),
    );
  }

  Widget _buildRasterizedPage(ui.Image? image) {
    if (image == null) {
      return Container(color: _cfg.theme.pageColor);
    }
    return RawImage(
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildGestureZones() {
    final double leftWidth = _canPrev ? _edgeZoneWidth() : 0;
    final double rightWidth = _canNext ? _edgeZoneWidth() : 0;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (leftWidth > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: leftWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanDown:
                  (DragDownDetails det) => _handlePanDown(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.prev,
                      zoneWidth: leftWidth,
                    ),
                  ),
              onPanStart:
                  (DragStartDetails det) => _handlePanStart(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.prev,
                      zoneWidth: leftWidth,
                    ),
                  ),
              onPanUpdate:
                  (DragUpdateDetails det) => _handlePanUpdate(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.prev,
                      zoneWidth: leftWidth,
                    ),
                  ),
              onPanEnd: (DragEndDetails det) => _handlePanEnd(det.velocity),
              onPanCancel: _onPanCancel,
              onTapUp:
                  (TapUpDetails det) => _handleTapUp(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.prev,
                      zoneWidth: leftWidth,
                    ),
                  ),
            ),
          ),
        if (rightWidth > 0)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: rightWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanDown:
                  (DragDownDetails det) => _handlePanDown(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.next,
                      zoneWidth: rightWidth,
                    ),
                  ),
              onPanStart:
                  (DragStartDetails det) => _handlePanStart(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.next,
                      zoneWidth: rightWidth,
                    ),
                  ),
              onPanUpdate:
                  (DragUpdateDetails det) => _handlePanUpdate(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.next,
                      zoneWidth: rightWidth,
                    ),
                  ),
              onPanEnd: (DragEndDetails det) => _handlePanEnd(det.velocity),
              onPanCancel: _onPanCancel,
              onTapUp:
                  (TapUpDetails det) => _handleTapUp(
                    _zoneToPageOffset(
                      det.localPosition,
                      direction: FlipDirection.next,
                      zoneWidth: rightWidth,
                    ),
                  ),
            ),
          ),
      ],
    );
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final Size pageSize = _fitPage(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        _onViewportChanged(pageSize);

        final bool contentReady =
            !_paginating &&
            widget.controller.totalPages > 0 &&
            _currentPageData != null;

        final bool ready =
            contentReady &&
            _currentAnimationImage != null &&
            (_dir == null ||
                _targetPageData() != null ||
                _belowImage() != null);
        final bool showAnimationOverlay = ready && _state != _Flip.idle;

        final CurlGeometry? geom = ready ? _buildGeometry() : null;
        final ui.Image? below = ready ? _belowImage() : null;
        final ui.Image? currentAnimationImage =
            ready ? _currentAnimationImage : null;
        final BookPage? targetPage = ready ? _targetPageData() : null;
        final bool useLiveTargetPage =
            showAnimationOverlay && geom != null && targetPage != null;

        if (contentReady && _state == _Flip.idle) {
          _scheduleVisibleSnapshotCapture();
        }

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
                child:
                    contentReady
                        ? Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (showAnimationOverlay)
                              IgnorePointer(
                                child:
                                    useLiveTargetPage
                                        ? _buildPageBody(targetPage)
                                        : _buildRasterizedPage(below),
                              )
                            else
                              _buildPageBody(
                                _currentPageData,
                                boundaryKey: _livePageBoundaryKey,
                              ),
                            if (showAnimationOverlay && geom != null)
                              IgnorePointer(
                                child: ClipPath(
                                  clipper: _PagePathClipper(
                                    geom.stationaryPath,
                                  ),
                                  child: _buildPageBody(_currentPageData),
                                ),
                              ),
                            if (showAnimationOverlay)
                              IgnorePointer(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    size: pageSize,
                                    painter: PageCurlPainter(
                                      currentImage: currentAnimationImage!,
                                      belowImage: below,
                                      backFaceImage: currentAnimationImage,
                                      geometry: geom,
                                      shadowStrength: _cfg.shadowStrength,
                                      shadowWidth: _cfg.shadowWidth,
                                      highlightStrength: _cfg.highlightStrength,
                                      backFaceTint:
                                          _cfg.theme.effectiveBackFaceTint,
                                      paintStationaryCurrentPage: false,
                                      paintBelowPageImage: !useLiveTargetPage,
                                    ),
                                  ),
                                ),
                              ),
                            _buildGestureZones(),
                          ],
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
        );
      },
    );
  }
}

class _PagePathClipper extends CustomClipper<Path> {
  const _PagePathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _PagePathClipper oldClipper) => true;
}
