import 'package:flutter/material.dart';

// 只需导入一个文件即可使用 SDK 全部能力
import 'package:page_demo/page_curl.dart';

void main() {
  runApp(const ExampleApp());
}

// ---------------------------------------------------------------------------
// Step 1: 准备页面数据 — 按 BookPage 格式提供标题 + 正文 + 页码
// ---------------------------------------------------------------------------

const List<BookPage> _samplePages = <BookPage>[
  BookPage(
    pageNumber: 1,
    title: '风从纸页间穿过',
    body: '午后四点，窗外的梧桐叶被一阵短风掀起，光线像细小的水纹落在桌角。'
        '我把手指按在书页边缘，听见纸纤维极轻的摩擦声，那声音像有人在远处慢慢折一封旧信。\n\n'
        '阅读最迷人的时刻，不是看见答案，而是看见问题在句子之间缓慢成形。'
        '每一页都像一扇半开的门，门后并不急着给出结论，只让你先站在门槛上，'
        '闻见木头、灰尘和雨后的空气。',
  ),
  BookPage(
    pageNumber: 2,
    title: '城市的背面',
    body: '清晨第一班地铁进站时，广告灯箱还没完全点亮，站台像一块尚未显影的底片。'
        '人群在同一条扶梯上升，却各自想着不同方向的路。\n\n'
        '有人把今天排成清单，有人把昨天折成口袋里的小纸条。'
        '城市从不缺少速度，缺少的是那一秒钟的停顿：'
        '你抬头，看见高架桥下的一束斜光，突然知道自己仍然在生活，而不只是赶路。',
  ),
  BookPage(
    pageNumber: 3,
    title: '手写体温度',
    body: '键盘让句子整齐，手写让句子有呼吸。'
        '当笔尖在纸上停顿，你能看见犹豫的形状；当一笔忽然加重，'
        '你也能看见决心落下去的重量。\n\n'
        '我们总以为记忆依靠容量，其实它更依靠触感。'
        '一张泛黄便签、一本压扁的笔记本、一次写错后划掉的名字，'
        '都在悄悄提醒：时间并不是流逝，它只是换了一种纹理继续存在。',
  ),
  BookPage(
    pageNumber: 4,
    title: '雨夜与路灯',
    body: '夜里十点半，雨开始变密。'
        '路灯把每一滴雨都照成短暂的金线，落地后立刻消失。'
        '我在便利店门口等雨小一点，听见冰柜压缩机低频运转，像远处海潮。\n\n'
        '那一刻忽然明白，所谓平静并不是环境安静，'
        '而是你能在嘈杂里辨认出自己的节奏。'
        '就像翻页时那道弧线，看起来柔软，却始终知道该落向哪里。',
  ),
  BookPage(
    pageNumber: 5,
    title: '最后一页之前',
    body: '真正难的不是结束，而是承认结束后仍然要继续。'
        '书快读到尾声时，我们会下意识放慢速度，'
        '仿佛只要翻页更慢一点，故事就能多停留几分钟。\n\n'
        '但纸页终究会落下，灯也终究会熄灭。'
        '好在你已经带走了一部分光：'
        '它会在下一次抬手翻页时，重新照亮你的指尖。',
  ),
];

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
// Step 2: 创建 Controller（集中传入页面 + 配置）
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

  @override
  void initState() {
    super.initState();

    // 创建 controller：传入页面数据 + 可选配置（有默认值）
    _controller = PageCurlController(
      pages: _samplePages,
      config: const PageCurlConfig(
        // 所有参数均有默认值，这里展示几个常用的自定义项：
        shadowStrength: 0.90,
        highlightStrength: 0.70,
        curlRadiusFactor: 1.18,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Step 4: 随时更新配置（用 copyWith 局部修改）
  void _updateConfig(PageCurlConfig Function(PageCurlConfig c) fn) {
    setState(() => _controller.config = fn(_controller.config));
  }

  // ---------------------------------------------------------------------------
  // Step 3: 把 PageCurlBookView 放入 Widget 树
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
              child: PageCurlBookView(
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
      child: Row(
        children: <Widget>[
          Text(
            'Page ${_currentPage + 1}/${_samplePages.length}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showPanel ? Icons.tune : Icons.tune_outlined,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _showPanel = !_showPanel),
          ),
        ],
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
                _slider('shadowStrength', c.shadowStrength, 0, 1.8,
                    (v) => _updateConfig((c) => c.copyWith(shadowStrength: v))),
                _slider('shadowWidth', c.shadowWidth, 10, 120,
                    (v) => _updateConfig((c) => c.copyWith(shadowWidth: v)),
                    fmt: (v) => v.toStringAsFixed(0)),
                _slider('highlightStrength', c.highlightStrength, 0, 1.6,
                    (v) => _updateConfig((c) => c.copyWith(highlightStrength: v))),
                _slider('spring', c.spring, 120, 900,
                    (v) => _updateConfig((c) => c.copyWith(spring: v)),
                    fmt: (v) => v.toStringAsFixed(0)),
                _slider('damping', c.damping, 8, 48,
                    (v) => _updateConfig((c) => c.copyWith(damping: v)),
                    fmt: (v) => v.toStringAsFixed(1)),
                _slider('commitThreshold', c.commitThreshold, 0.20, 0.85,
                    (v) => _updateConfig((c) => c.copyWith(commitThreshold: v))),
                _slider('curlRadius', c.curlRadiusFactor, 0.55, 1.85,
                    (v) => _updateConfig((c) => c.copyWith(curlRadiusFactor: v)),
                    fmt: (v) => '${v.toStringAsFixed(2)}x'),
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
