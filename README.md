# vellum_engine

`vellum_engine` 是一个面向 Flutter 的翻页动画 SDK，重点提供更接近真实纸张的卷页体验，同时兼顾阅读场景下的文本选择、复制、图片混排和自动分页。

当前这版更适合：

- 小说阅读器、图文阅读器
- 画册、绘本、相册式内容展示
- 需要“卷页感”而不是普通 `PageView` 的内容场景

## 功能特性

- 支持点击边缘翻页和拖拽翻页
- 支持角落卷起和中段水平卷起
- 支持真实文本页面，静止态可选中文本并复制
- 支持图文混排
- 支持根据可用区域自动分页
- 支持手动分页、自动分页、builder 三种接入模式
- 支持程序化翻页：上一页、下一页、跳转、动画跳转
- 支持主题、字体、阴影、阻尼等配置

## 安装方式

当前仓库 `publish_to: none`，适合先以本地依赖接入。

```yaml
dependencies:
  vellum_engine:
    path: ../vellum_engine-main
```

然后执行：

```bash
flutter pub get
```

## 快速开始

先导入：

```dart
import 'package:vellum_engine/page_curl.dart';
```

最简单的用法是先创建 `PageCurlController`，再把 `PageCurlBookView` 放进页面里：

```dart
final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(
      pageNumber: 1,
      title: '第一页',
      body: '这里是正文内容。',
    ),
    BookPage(
      pageNumber: 2,
      title: '第二页',
      body: '这里是第二页正文内容。',
    ),
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

## 三种接入模式

### 1. 手动分页模式

如果你的主 App 已经自己分页完成，可以直接传 `List<BookPage>`：

```dart
final controller = PageCurlController(
  pages: const <BookPage>[
    BookPage(pageNumber: 1, title: 'Chapter 1', body: '...'),
    BookPage(pageNumber: 2, title: 'Chapter 2', body: '...'),
  ],
);
```

适合：

- 已经有分页引擎
- 漫画、绘本、短内容展示
- 服务端已经切页的数据

### 2. 自动分页模式

如果你希望 SDK 根据屏幕可用区域自动拆页，使用 `BookDocument`。

纯文本快捷写法：

```dart
final controller = PageCurlController.document(
  document: BookDocument.text(
    title: '第一章',
    text: longText,
  ),
);
```

图文混排写法：

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
      const ParagraphBlock('这里是后续正文。'),
    ],
  ),
);
```

适合：

- 长文本阅读
- 图文混排内容
- 主 App 只提供原始内容，由 SDK 负责分页

### 3. Builder 模式

如果你的页面数据来自数据库、接口或按需加载，可以使用 builder 模式：

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

适合：

- 大量页面按需加载
- 远程数据源
- 希望自行控制页面构造逻辑

## 页面内容模型

### `BookPage`

手动分页时使用。

```dart
const BookPage(
  pageNumber: 1,
  title: '标题',
  body: '正文',
)
```

或者使用富内容版本：

```dart
const BookPage.rich(
  pageNumber: 1,
  contents: <PageContent>[
    TitleBlock('标题'),
    ParagraphBlock('正文'),
  ],
)
```

### `BookDocument`

自动分页时使用，表示“还没有被切页的一整段内容”。

```dart
BookDocument(
  contents: <PageContent>[
    TitleBlock('标题'),
    ParagraphBlock('正文'),
  ],
  startPageNumber: 1,
)
```

### `PageContent` 支持的内容块

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

注意：`ImageBlock` 目前接收的是 `Uint8List bytes`，也就是已经加载好的图片二进制数据。

## 控制器 API

`PageCurlController` 负责内容和程序化翻页控制。

常用方法：

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

你也可以在运行时动态修改配置：

```dart
controller.config = controller.config.copyWith(
  shadowStrength: 0.95,
  highlightStrength: 0.75,
  curlRadiusFactor: 1.2,
);
```

## 配置项说明

`PageCurlConfig` 主要包含以下几类配置：

- 动画手感：`spring`、`damping`、`commitThreshold`
- 卷页形态：`curlRadiusFactor`
- 光影效果：`shadowStrength`、`shadowWidth`、`highlightStrength`
- 页面比例：`pageRatio`
- 触发区域：`edgeZoneWidth`
- 排版样式：`typography`
- 页面主题：`theme`

示例：

```dart
const PageCurlConfig(
  shadowStrength: 0.90,
  highlightStrength: 0.70,
  curlRadiusFactor: 1.18,
  pageRatio: 0.70,
  edgeZoneWidth: 84,
  theme: BookTheme.paperYellow,
  typography: BookTypography(
    horizontalPadding: 28,
    topPadding: 34,
    bottomPadding: 28,
    titleSize: 26,
    bodySize: 16,
  ),
)
```

内置主题：

- `BookTheme.white`
- `BookTheme.black`
- `BookTheme.gray`
- `BookTheme.paperYellow`
- `BookTheme.realistic`

## 阅读交互说明

- 静止态页面使用真实文本 widget，支持长按选择和复制文本
- 翻页动画开始后，会切到卷页动画层
- 当前页优先使用真实可见页快照
- 目标页优先使用真实 widget 页，以减少动画页与落地页的视觉切换

这意味着：

- 文本阅读场景下，体验会比“纯截图翻页”更自然
- 但真正卷起的 flap 部分仍然是动画纹理层，这是为了保留卷页效果

## 适合什么场景

推荐：

- 小说阅读器
- 长文阅读
- 图文卡片阅读
- 绘本、画册、相册

不推荐直接拿来当完整电子书系统的全部能力：

- 目前不包含 EPUB 解析
- 目前不包含 Markdown/HTML 转内容块适配层
- 目前不包含批注、高亮、目录、搜索等完整阅读器能力

更准确地说，这个仓库当前更像是“可集成的翻页阅读组件”，不是“全功能电子书内核”。

## 一个完整示例

仓库已经提供了完整示例：

- [example/lib/main.dart](/Users/ryu_japanpaymottogroup/WorkSpace/rya/vellum_engine-main/example/lib/main.dart)

示例里演示了：

- 异步准备图片
- 构造 `BookDocument`
- 自动分页
- 页面选择复制
- 控制器按钮翻页
- 动态调节翻页参数

## 建议接入方式

如果你在做阅读软件，建议优先按下面思路接入：

1. 主 App 负责拿到原始内容
2. 将内容转换成 `BookDocument` 或 `BookPage`
3. 使用 `PageCurlController` 管理内容和翻页
4. 把 `PageCurlBookView` 嵌入你的阅读页
5. 用 `onPageChanged` 同步阅读进度

如果你的内容是长文本，优先用 `BookDocument`。  
如果你的内容已经分页，优先用 `List<BookPage>`。  
如果你的内容量很大且按需加载，优先用 builder 模式。

## 当前限制

- 图片需要先转成 `Uint8List`
- 富文本块模型还比较轻量
- 目前主要面向横向单页阅读
- 超复杂排版需求仍建议主 App 自己做更强的排版层

## License

MIT License。


