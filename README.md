# vellum_engine

Language / 言語 / 语言:
[中文](#中文) | [日本語](#日本語) | [English](#english)

---

## Demo Recordings

### Android
<video controls preload="metadata" width="360">
  <source src="./record/android_record.mp4" type="video/mp4">
</video>

### iOS
<video controls preload="metadata" width="360">
  <source src="./record/ios_record.mp4" type="video/mp4">
</video>

---

## 中文

`vellum_engine` 是一个面向 Flutter 的翻页动画 SDK，提供更接近真实纸张的卷页体验，同时兼顾阅读场景下的文本选择、复制、图片混排和自动分页。

### 功能特性

- 支持点击边缘翻页和拖拽翻页
- 支持角落卷起和中段水平卷起
- 支持静止态真实文本页，可长按选择并复制文本
- 支持图片、标题、正文、引用、列表、间距块
- 支持自动分页
- 支持手动分页、自动分页、builder 三种接入模式
- 支持程序化翻页：上一页、下一页、跳转、动画跳转
- 支持主题、排版、阴影、阻尼等配置

### 安装方式

当前仓库 `publish_to: none`，建议先用本地依赖：

```yaml
dependencies:
  vellum_engine:
    path: ../vellum_engine
```

然后执行：

```bash
flutter pub get
```

### 快速开始

```dart
import 'package:vellum_engine/page_curl.dart';

final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: '第一页', body: '这里是正文内容。'),
    BookPage(pageNumber: 2, title: '第二页', body: '这里是第二页正文内容。'),
  ],
  config: const PageCurlConfig(),
);

PageCurlBookView(
  controller: controller,
  onPageChanged: (int page) {
    debugPrint('当前页: $page');
  },
);
```

### 三种接入模式

#### 1. 手动分页

适合主 App 已经分页完成的场景：

```dart
final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: 'Chapter 1', body: '...'),
    BookPage(pageNumber: 2, title: 'Chapter 2', body: '...'),
  ],
);
```

#### 2. 自动分页

适合主 App 提供原始文本或图文内容，由 SDK 按屏幕可用区域自动拆页：

```dart
final controller = PageCurlController.document(
  document: BookDocument.text(
    title: '第一章',
    text: longText,
  ),
);
```

图文混排示例：

```dart
final controller = PageCurlController.document(
  document: BookDocument(
    contents: <PageContent>[
      const TitleBlock('风从纸页间穿过'),
      const ParagraphBlock('这里是一段正文。'),
      const QuoteBlock('真正好的翻页，不该让用户去对准像素。'),
      const BulletListBlock(<String>[
        '支持自动分页',
        '支持图片',
        '支持复制文本',
      ]),
      ImageBlock(
        bytes: imageBytes,
        height: 140,
        caption: '图片说明',
      ),
    ],
  ),
);
```

#### 3. Builder 模式

适合大量页面按需加载：

```dart
final controller = PageCurlController.builder(
  pageCount: 100,
  pageBuilder: (int pageIndex) async {
    return BookPage(
      pageNumber: pageIndex + 1,
      title: '第 ${pageIndex + 1} 页',
      body: '这里是动态加载的页面内容',
    );
  },
);
```

### 内容模型

`PageContent` 当前支持：

- `TitleBlock`
- `ParagraphBlock`
- `QuoteBlock`
- `BulletListBlock`
- `ImageBlock`
- `SpacingBlock`

图片块示例：

```dart
ImageBlock(
  bytes: imageBytes,
  height: 160,
  caption: '图片说明',
)
```

注意：`ImageBlock` 目前接收 `Uint8List bytes`。

### 控制器 API

```dart
controller.nextPage();
controller.previousPage();
controller.jumpToPage(10);
controller.animateToPage(10);
```

常用属性：

```dart
controller.totalPages;
controller.config;
```

运行时动态调整：

```dart
controller.config = controller.config.copyWith(
  shadowStrength: 0.95,
  highlightStrength: 0.75,
  curlRadiusFactor: 1.2,
);
```

### 配置项

`PageCurlConfig` 常用配置包括：

- 动画手感：`spring`、`damping`、`commitThreshold`
- 卷页形态：`curlRadiusFactor`
- 光影效果：`shadowStrength`、`shadowWidth`、`highlightStrength`
- 页面比例：`pageRatio`
- 触发区域：`edgeZoneWidth`
- 排版样式：`typography`
- 页面主题：`theme`

内置主题：

- `BookTheme.white`
- `BookTheme.black`
- `BookTheme.gray`
- `BookTheme.paperYellow`
- `BookTheme.realistic`

### 阅读交互说明

- 静止态页面使用真实文本 widget，支持长按选择和复制
- 翻页开始后切到卷页动画层
- 当前页优先使用真实可见页快照
- 目标页优先使用真实 widget 页，以减少动画页与落地页的突兀切换

### 适合什么场景

推荐：

- 小说阅读器
- 长文阅读
- 图文阅读
- 绘本、画册、相册

当前不包含：

- EPUB 解析
- Markdown / HTML 转换层
- 批注、高亮、目录、搜索等完整阅读器能力

### 示例

完整示例见：

- [example/lib/main.dart](./example/lib/main.dart)

### License

MIT License. Full text: [LICENSE](./LICENSE)

---

## 日本語

`vellum_engine` は Flutter 向けのページカール SDK です。紙をめくるようなアニメーションに加えて、読書向けのテキスト選択、コピー、画像混在、そして自動ページ分割をサポートします。

### 特徴

- タップとドラッグによるページめくり
- 角からのカールと中央付近の水平カール
- 静止時は実際のテキスト Widget を表示し、選択とコピーに対応
- 画像、見出し、本文、引用、箇条書き、余白ブロックに対応
- 自動ページ分割に対応
- 手動ページ、ドキュメント自動分割、builder の 3 モードを提供
- プログラム制御でページ送り可能

### 導入

```yaml
dependencies:
  vellum_engine:
    path: ../vellum_engine
```

```bash
flutter pub get
```

### クイックスタート

```dart
import 'package:vellum_engine/page_curl.dart';

final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: '1ページ目', body: '本文'),
    BookPage(pageNumber: 2, title: '2ページ目', body: '本文'),
  ],
);

PageCurlBookView(controller: controller);
```

### 3つの利用モード

#### 1. 手動ページモード

すでにページ分割済みのデータを渡す場合：

```dart
final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: 'Chapter 1', body: '...'),
  ],
);
```

#### 2. 自動ページ分割モード

画面サイズに応じて SDK にページ分割させる場合：

```dart
final controller = PageCurlController.document(
  document: BookDocument.text(
    title: '第1章',
    text: longText,
  ),
);
```

#### 3. Builder モード

大量ページを遅延ロードする場合：

```dart
final controller = PageCurlController.builder(
  pageCount: 100,
  pageBuilder: (int index) async {
    return BookPage(
      pageNumber: index + 1,
      title: 'Page ${index + 1}',
      body: 'Lazy loaded content',
    );
  },
);
```

### コンテンツブロック

対応している `PageContent`：

- `TitleBlock`
- `ParagraphBlock`
- `QuoteBlock`
- `BulletListBlock`
- `ImageBlock`
- `SpacingBlock`

### Controller API

```dart
controller.nextPage();
controller.previousPage();
controller.jumpToPage(10);
controller.animateToPage(10);
```

### 備考

- 静止状態ではテキスト選択が可能です
- めくり中はアニメーションレイヤーに切り替わります
- 現在ページは表示中の実ページスナップショットを優先して使用します
- 目標ページは可能な限り実 Widget ページを使い、切り替えの違和感を抑えています

### サンプル

- [example/lib/main.dart](./example/lib/main.dart)

### License

MIT License. Full text: [LICENSE](./LICENSE)

---

## English

`vellum_engine` is a Flutter page-curl SDK designed for realistic page turning while still supporting reading-oriented features such as text selection, copy, mixed image/text content, and automatic pagination.

### Features

- Edge tap and drag page turning
- Corner curl and middle horizontal curl
- Real text widgets while idle, with text selection and copy support
- Rich content blocks for text and images
- Automatic pagination based on available viewport size
- Three integration modes: manual pages, auto-paginated document, and builder
- Programmatic page control
- Configurable theme, typography, shadows, and motion

### Installation

This repository is currently `publish_to: none`, so local path dependency is recommended:

```yaml
dependencies:
  vellum_engine:
    path: ../vellum_engine
```

```bash
flutter pub get
```

### Quick Start

```dart
import 'package:vellum_engine/page_curl.dart';

final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: 'Page 1', body: 'Body text'),
    BookPage(pageNumber: 2, title: 'Page 2', body: 'Body text'),
  ],
);

PageCurlBookView(controller: controller);
```

### Integration Modes

#### 1. Manual Page Mode

Use this when your app already has paginated data:

```dart
final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: 'Chapter 1', body: '...'),
  ],
);
```

#### 2. Auto Pagination Mode

Use `BookDocument` when you want the SDK to paginate content automatically:

```dart
final controller = PageCurlController.document(
  document: BookDocument.text(
    title: 'Chapter 1',
    text: longText,
  ),
);
```

#### 3. Builder Mode

Use this for large datasets or lazy loading:

```dart
final controller = PageCurlController.builder(
  pageCount: 100,
  pageBuilder: (int index) async {
    return BookPage(
      pageNumber: index + 1,
      title: 'Page ${index + 1}',
      body: 'Lazy loaded content',
    );
  },
);
```

### Content Blocks

Supported `PageContent` types:

- `TitleBlock`
- `ParagraphBlock`
- `QuoteBlock`
- `BulletListBlock`
- `ImageBlock`
- `SpacingBlock`

### Controller API

```dart
controller.nextPage();
controller.previousPage();
controller.jumpToPage(10);
controller.animateToPage(10);
```

### Notes

- Idle pages use real text widgets, so users can select and copy text
- Once page turning starts, the SDK switches to the animation layer
- The current page prefers a snapshot captured from the visible live page
- The target page prefers a live widget page whenever possible, reducing the visual jump between animation and settled state

### Example

- [example/lib/main.dart](./example/lib/main.dart)

### License

MIT License. Full text: [LICENSE](./LICENSE)
