import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vellum_engine/page_curl.dart';

void main() {
  runApp(const ExampleApp());
}

// ---------------------------------------------------------------------------
// Step 1: Prepare page data
//
//   Option A — text only (backward compatible): BookPage(title: ..., body: ...)
//   Option B — rich mixed content: BookPage.rich(contents: [ TitleBlock, ParagraphBlock, ImageBlock, ... ])
// ---------------------------------------------------------------------------

Future<Uint8List> _loadImageBytes(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List();
}

Future<List<BookPage>> _buildSamplePages() async {
  final Uint8List page1Image = await _loadImageBytes('assets/example1.webp');
  final Uint8List page2Image = await _loadImageBytes('assets/example2.jpeg');
  final Uint8List page3Image = await _loadImageBytes('assets/example3.jpg');

  return <BookPage>[
    BookPage.rich(
      pageNumber: 1,
      contents: <PageContent>[
        const TitleBlock('English Page'),
        ImageBlock(bytes: page1Image, height: 160, caption: 'example1.webp'),
        const ParagraphBlock(
          'A quiet train leaves the station at dawn, and the windows slowly fill with light.',
        ),
        const ParagraphBlock(
          'This demo page is written in English and includes one local asset image.',
        ),
      ],
    ),
    BookPage.rich(
      pageNumber: 2,
      contents: <PageContent>[
        const TitleBlock('日本語ページ'),
        ImageBlock(bytes: page2Image, height: 160, caption: 'example2.jpeg'),
        const ParagraphBlock(
          '雨上がりの歩道には、街灯の光が小さな鏡のように並んでいました。',
        ),
        const ParagraphBlock('このページは日本語表示と画像描画の確認用です。'),
      ],
    ),
    BookPage.rich(
      pageNumber: 3,
      contents: <PageContent>[
        const TitleBlock('中文页面'),
        ImageBlock(bytes: page3Image, height: 160, caption: 'example3.jpg'),
        const ParagraphBlock(
          '傍晚的风从河面吹来，书页边缘轻轻颤动，像在提醒我们继续读下去。',
        ),
        const ParagraphBlock('这一页用于中文文本和图片渲染测试。'),
      ],
    ),
  ];
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Page Curl Example',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C7E54),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Create the controller (provide pages + config in one place)
// ---------------------------------------------------------------------------

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  late final PageCurlController _controller;
  int _currentPage = 0;
  bool _showPanel = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Create the controller with empty pages first, then set sample pages.
    _controller = PageCurlController(
      pages: const <BookPage>[],
      config: const PageCurlConfig(
        shadowStrength: 0.90,
        highlightStrength: 0.70,
        curlRadiusFactor: 1.18,
      ),
    );
    _controller.addListener(_handleControllerChanged);
    _loadPages();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadPages() async {
    final List<BookPage> pages = await _buildSamplePages();
    if (!mounted) return;
    setState(() {
      _controller.pages = pages;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // Step 4: Update config anytime (partial updates via copyWith)
  void _updateConfig(PageCurlConfig Function(PageCurlConfig c) fn) {
    setState(() => _controller.config = fn(_controller.config));
  }

  // ---------------------------------------------------------------------------
  // Step 3: Put PageCurlBookView into the widget tree
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17120F),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : PageCurlBookView(
                        controller: _controller,
                        onPageChanged: (int page) {
                          setState(() => _currentPage = page);
                        },
                      ),
            ),
            if (_showPanel) _buildTuningPanel(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Page ${_currentPage + 1}/${_controller.totalPages}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed:
                    _currentPage > 0 ? () => _controller.previousPage() : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed:
                    _currentPage + 1 < _controller.totalPages
                        ? () => _controller.nextPage()
                        : null,
              ),
              IconButton(
                icon: Icon(
                  _showPanel ? Icons.tune : Icons.tune_outlined,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() => _showPanel = !_showPanel),
              ),
            ],
          ),
          _buildThemePicker(),
        ],
      ),
    );
  }

  Widget _buildThemePicker() {
    final BookTheme current = _controller.config.theme;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BookTheme.presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, int i) {
          final BookTheme t = BookTheme.presets[i];
          final bool selected = t.name == current.name;
          return ChoiceChip(
            label: Text(t.name),
            selected: selected,
            onSelected: (_) => _updateConfig((c) => c.copyWith(theme: t)),
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? Colors.black : Colors.white70,
            ),
            selectedColor: Colors.white,
            backgroundColor: Colors.white12,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildTuningPanel() {
    final PageCurlConfig c = _controller.config;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF201A15),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                _slider(
                  'shadowStrength',
                  c.shadowStrength,
                  0,
                  1.8,
                  (v) => _updateConfig((c) => c.copyWith(shadowStrength: v)),
                ),
                _slider(
                  'shadowWidth',
                  c.shadowWidth,
                  10,
                  120,
                  (v) => _updateConfig((c) => c.copyWith(shadowWidth: v)),
                  fmt: (v) => v.toStringAsFixed(0),
                ),
                _slider(
                  'highlightStrength',
                  c.highlightStrength,
                  0,
                  1.6,
                  (v) => _updateConfig((c) => c.copyWith(highlightStrength: v)),
                ),
                _slider(
                  'spring',
                  c.spring,
                  120,
                  900,
                  (v) => _updateConfig((c) => c.copyWith(spring: v)),
                  fmt: (v) => v.toStringAsFixed(0),
                ),
                _slider(
                  'damping',
                  c.damping,
                  8,
                  48,
                  (v) => _updateConfig((c) => c.copyWith(damping: v)),
                  fmt: (v) => v.toStringAsFixed(1),
                ),
                _slider(
                  'commitThreshold',
                  c.commitThreshold,
                  0.20,
                  0.85,
                  (v) => _updateConfig((c) => c.copyWith(commitThreshold: v)),
                ),
                _slider(
                  'curlRadius',
                  c.curlRadiusFactor,
                  0.55,
                  1.85,
                  (v) => _updateConfig((c) => c.copyWith(curlRadiusFactor: v)),
                  fmt: (v) => '${v.toStringAsFixed(2)}x',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String Function(double)? fmt,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(
                fmt?.call(value) ?? value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
