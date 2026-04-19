import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

/// Generates a solid gradient placeholder image (for demo use only).
/// In real projects, use actual image bytes.
Future<Uint8List> _generatePlaceholderImage(
  int w,
  int h,
  Color from,
  Color to,
) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w.toDouble(), h.toDouble()),
        [from, to],
      ),
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// Builds a sample document.
/// The SDK auto-paginates it based on the available page viewport.
Future<BookDocument> _buildSampleDocument() async {
  final Uint8List imgA = await _generatePlaceholderImage(
    800,
    400,
    const Color(0xFFB8D4E3),
    const Color(0xFF7EB5D6),
  );
  final Uint8List imgB = await _generatePlaceholderImage(
    800,
    500,
    const Color(0xFFE3C8A8),
    const Color(0xFFD4A06A),
  );

  return BookDocument(
    contents: <PageContent>[
      const TitleBlock('风从纸页间穿过'),
      const ParagraphBlock(
        '午后四点，窗外的梧桐叶被一阵短风掀起，光线像细小的水纹落在桌角。'
        '我把手指按在书页边缘，听见纸纤维极轻的摩擦声，那声音像有人在远处慢慢折一封旧信。',
      ),
      const ParagraphBlock(
        '阅读最迷人的时刻，不是看见答案，而是看见问题在句子之间缓慢成形。'
        '每一页都像一扇半开的门，门后并不急着给出结论，只让你先站在门槛上，'
        '闻见木头、灰尘和雨后的空气。',
      ),
      const QuoteBlock('真正好的翻页，不该让用户去对准像素，而该让动作自然落地。'),
      const TitleBlock('城市的背面'),
      const ParagraphBlock('清晨第一班地铁进站时，广告灯箱还没完全点亮，站台像一块尚未显影的底片。'),
      ImageBlock(bytes: imgA, height: 120, caption: '站台的晨光'),
      const ParagraphBlock(
        '有人把今天排成清单，有人把昨天折成口袋里的小纸条。'
        '城市从不缺少速度，缺少的是那一秒钟的停顿。',
      ),
      const TitleBlock('手写体温度'),
      const ParagraphBlock('键盘让句子整齐，手写让句子有呼吸。'),
      ImageBlock(bytes: imgB, height: 100, caption: '泛黄便签'),
      const SpacingBlock(8),
      const ParagraphBlock(
        '一张泛黄便签、一本压扁的笔记本、一次写错后划掉的名字，'
        '都在悄悄提醒：时间并不是流逝，它只是换了一种纹理继续存在。',
      ),
      const TitleBlock('雨夜与路灯'),
      const ParagraphBlock(
        '夜里十点半，雨开始变密。'
        '路灯把每一滴雨都照成短暂的金线，落地后立刻消失。'
        '我在便利店门口等雨小一点，听见冰柜压缩机低频运转，像远处海潮。',
      ),
      const ParagraphBlock(
        '那一刻忽然明白，所谓平静并不是环境安静，'
        '而是你能在嘈杂里辨认出自己的节奏。'
        '就像翻页时那道弧线，看起来柔软，却始终知道该落向哪里。',
      ),
      const BulletListBlock(<String>[
        '文本可以长按选择并复制',
        '图片会参与自动分页计算',
        '支持手势翻页和控制器按钮翻页',
      ]),
      const TitleBlock('最后一页之前'),
      const ParagraphBlock(
        '真正难的不是结束，而是承认结束后仍然要继续。'
        '书快读到尾声时，我们会下意识放慢速度，'
        '仿佛只要翻页更慢一点，故事就能多停留几分钟。',
      ),
      const ParagraphBlock(
        '但纸页终究会落下，灯也终究会熄灭。'
        '好在你已经带走了一部分光：'
        '它会在下一次抬手翻页时，重新照亮你的指尖。',
      ),
    ],
  );
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

    // Create the controller with empty content first, then set the
    // auto-paginated document after async image data is ready.
    _controller = PageCurlController(
      pages: const <BookPage>[],
      config: const PageCurlConfig(
        shadowStrength: 0.90,
        highlightStrength: 0.70,
        curlRadiusFactor: 1.18,
      ),
    );
    _controller.addListener(_handleControllerChanged);
    _loadDocument();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDocument() async {
    final BookDocument document = await _buildSampleDocument();
    if (!mounted) return;
    setState(() {
      _controller.document = document;
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
