# JustRead

📖 一款基于 Flutter + Riverpod 的轻量级 Android EPUB 电子书阅读器。

支持本地导入 EPUB 文件、书架管理、阅读进度追踪、书签系统和暗色模式，手写逐行分页算法提供流畅的翻页体验。

## ✨ 功能特性

- 📂 **本地导入** — 通过文件选择器导入 EPUB 文件
- 📚 **书架管理** — 网格封面展示，长按删除/查看详情，书名首字占位封面
- 📖 **双阅读模式** — 翻页模式（TextPainter 逐行分页）与上下滚动模式一键切换
- 🔖 **书签系统** — 添加/删除/跳转书签，书签数据独立持久化
- 🌙 **暗色模式** — 日间/夜间模式切换，偏好持久化
- 🔤 **字体调节** — 12px ~ 36px 无级调节，分页实时重算
- 📊 **阅读进度** — 章节级 + 章节内精确定位，进度条百分比显示，跨模式双向转换
- 🖼️ **封面提取** — 三层 fallback 策略自动解析 EPUB 封面
- 📑 **章节目录** — 完整 TOC，点击跳转任意章节

## 🏗️ 技术架构

### 状态管理：Riverpod

项目从 `StatefulWidget + setState` 重构为 Riverpod 分层架构：

```
┌─────────────────────────────────────┐
│  UI Layer (lib/screens/, widgets/)  │  ← ConsumerWidget / ConsumerStatefulWidget
├─────────────────────────────────────┤
│  State Layer (lib/providers/)        │  ← Notifier + immutable State
│  ReaderProvider / LibraryProvider    │
│  BookmarkProvider                    │
├─────────────────────────────────────┤
│  Service Layer (lib/services/)       │  ← EpubService (Singleton)
│  EPUB 解析 · 书库管理 · 进度持久化    │
├─────────────────────────────────────┤
│  Model Layer (lib/models/)           │  ← Book / Chapter / Bookmark
└─────────────────────────────────────┘
```

- **ReaderNotifier**: 管理阅读核心状态（章节、页码、模式、字号、暗色偏好），所有状态变更自动触发进度持久化
- **LibraryNotifier**: 管理书架（导入/删除/刷新），响应式更新 UI
- **BookmarkNotifier**: 管理书签 CRUD，独立 JSON 文件存储

### 分页算法

手写基于 `TextPainter` 的**逐行分页算法**，不使用 WebView：

1. **TextPainter.layout()** 获取全文布局
2. **computeLineMetrics()** 获取每行的精确高度和基线
3. 按屏幕可用高度逐行累加，超出高度时切分——通过 `getPositionForOffset()` 反查字符偏移量
4. 输出 `List<String>` 分页数组

**为什么不用 WebView？**
- WebView 渲染受 CSS/JS 影响，进度定位不精确
- 原生 `TextPainter` 分页高度可精确定量计算
- 翻页和滚动模式可**双向转换**：`scrollOffset ↔ pageIndex`

### 进度双向转换

| 方向 | 算法 |
|------|------|
| 翻页 → 滚动 | `scrollOffset = currentPage / (totalPages - 1) × maxScrollExtent` |
| 滚动 → 翻页 | `pageIndex = round(scrollOffset / maxScrollExtent × (totalPages - 1))` |
| 全局进度 | `章节基数 + 章节内比例 / 章节总数` |

### 文件拆分

```
lib/
├── main.dart                     # ProviderScope 入口
├── models/
│   └── book.dart                 # Book, Chapter, Bookmark 数据模型
├── providers/
│   ├── reader_provider.dart      # 阅读器状态管理
│   ├── library_provider.dart     # 书架状态管理
│   └── bookmark_provider.dart    # 书签状态管理
├── screens/
│   ├── bookshelf_screen.dart     # 书架页面 (ConsumerWidget)
│   └── reader_screen.dart        # 阅读器主页面 (ConsumerStatefulWidget)
├── services/
│   └── epub_service.dart         # EPUB 解析 + 书库 + 书签持久化
└── widgets/
    ├── reader_top_bar.dart       # 顶部栏（返回 + 章节标题）
    ├── reader_bottom_bar.dart    # 底部控制栏（进度/字体/书签/模式）
    ├── bookmark_sheet.dart       # 书签列表 BottomSheet
    ├── toc_sheet.dart            # 目录 BottomSheet
    └── font_size_dialog.dart     # 字号调节对话框
```

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Flutter / Dart | 跨平台移动框架 |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | 响应式状态管理 |
| [epubx](https://pub.dev/packages/epubx) | EPUB 文件解析 |
| [file_picker](https://pub.dev/packages/file_picker) | 本地文件选择 |
| [path_provider](https://pub.dev/packages/path_provider) | 本地文件存储 |
| [permission_handler](https://pub.dev/packages/permission_handler) | 存储权限管理 |
| [uuid](https://pub.dev/packages/uuid) | 书签 ID 生成 |

## 🚀 构建与安装

### 环境要求

- Flutter SDK ^3.12.2
- Android SDK
- Java JDK 17+

### 构建 APK

```bash
cd justRead
flutter pub get
flutter build apk --release        # 通用 APK
flutter build apk --split-per-abi  # 按 CPU 拆分（体积更小）
```

构建产物位于 `build/app/outputs/flutter-apk/`。

### 直接安装到设备

```bash
flutter install
```

## 📋 环境配置

1. 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)
2. 配置 Android Studio 或 Android 命令行工具
3. 配置 Java JDK 17+
4. 连接 Android 设备或启动模拟器

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

## 👤 作者

- GitHub: [@Tsyh-0](https://github.com/Tsyh-0)
