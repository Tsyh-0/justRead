# justRead 待修复问题清单

> 最后更新: 2026-06-29（进度恢复修复）

---

## 高优先级

### 1. 字体缩放后分页未重算
- **状态**: ✅ 已修复（两次迭代）
- **根因**: ① A+/A- 按钮只调 `setFontSize` 未触发重算；② 重算后用简单 clamp 恢复页码，字号变化导致内容位置漂移
- **修复**: ReaderBottomBar 新增 `onFontSizeChanged` 回调；`_recalculatePages` 改为按内容进度比例（`oldPage/oldTotal`）恢复，而非机械 clamp 旧页码。分页算法参数化。

### 2. 信件/序章/尾声等特殊段落排版异常
- **状态**: ✅ 已修复
- **根因**: EPUB 文件使用 `\r\n`（CRLF）换行符。`_stripHtml` 末尾的 `\n{3,}` 正则只匹配 LF（`\n`），`\r` 字符将连续 `\n` 隔断，导致合并正则完全失效。
- **验证**: 用龙族全套 EPUB（6册/152章）诊断，修复前开篇/序章/尾声等特殊段落 strip 后存在大量多余空行；修复后所有章节 `\n{3,}` 出现次数 = 0，段落间距统一为单个空行。
- **修复**: 在 `\n{3,}` 合并之前增加 `\r\n` → `\n` 和 `\r` → `\n` 的换行符归一化。
- **位置**: `reader_screen.dart` → `_stripHtml()`

### 3. 翻页点击区域过大
- **状态**: ✅ 已修复（两次迭代）
- **根因**: 初始用 `/5` 改左区但对右区用 `zoneWidth * 2`，导致右区反从 33% 扩至 60%
- **修复**: 右区边界改为 `width - zoneWidth`，左右各占 20%，中区 60%。滑动手势不动。

### 4. 退出阅读器时进度丢失（已修复）
- **状态**: ✅ 已修复 — `dispose()` 中调用 `notifier.onExit()`

### 5. 书架不显示阅读进度（已修复）
- **状态**: ✅ 已修复 — 进度条 + 百分比标签始终可见

### 6. dark mode 不持久化（已修复）
- **状态**: ✅ 已修复 — `Book.isDarkMode` 序列化到 library.json

### 7. 封面页无法操作（已修复）
- **状态**: ✅ 已修复 — Container 缺少 `width: double.infinity` 导致 GestureDetector 区域坍缩

### 8. 退出再进入崩溃（已修复）
- **状态**: ✅ 已修复 — `didChangeDependencies` 中不在 build 期间修改 provider

---

## 中优先级

### 9. EPUB 图片显示
- **现象**: EPUB 中的插图（封面图片、文中图片）无法显示，只显示占位文字。
- **分析**: `_stripHtml` 移除了 `<img>` 标签。要支持图片需要：Chapter 模型存储图片 bytes、滚动模式用 `RichText+WidgetSpan` 嵌入、翻页模式需要特殊处理。
- **位置**: `reader_screen.dart` → `_stripHtml()` / `epub_service.dart` → `parseEpubBytes()`
- **修复方向**: 见上方"图片支持方案"讨论。

### 10. 旧数据兼容
- **状态**: ✅ 已修复
- **处理**: `ReaderNotifier.init()` 强制 `isPageMode=true`；`Book.fromJson` 对缺失 `isPageMode` 字段默认返回 `true`（已同步修正测试）。

### 11. 滚动模式残留代码清理
- **现象**: `_handleModeToggle` 已改为提示弹窗，但 `_pendingScrollProgress`、`_scrollController` 滚动监听等代码仍存在，且 `_buildScrollMode` / `_buildStaticContent` 仍被调用。
- **修复方向**: 这是为未来 PDF 支持预留的，暂不清理。

---

## 低优先级 / 优化建议

### 12. 书籍封面 fallback
- **状态**: ✅ 已完成 — `_firstDisplayChar` 已实现 CJK 首字 / Latin 首字母大写 / 回退方案，配合 10 色调色板。

### 13. 书架导入去重
- **现象**: 重复导入同一文件会产生两本一样的书。
- **状态**: ✅ 已修复 — `importBook` 中通过 bookId 去重，保留旧阅读进度。

---

## 已完成架构重构

- **状态管理**: 从 `StatefulWidget+setState` 引入 Riverpod（ReaderNotifier / LibraryNotifier / BookmarkNotifier）
- **文件拆分**: reader_screen 拆分为 TopBar / BottomBar / TocSheet / BookmarkSheet / FontSizeDialog
- **书签系统**: 添加/删除/跳转书签，独立 JSON 持久化
- **EPUB 默认翻页模式**: 新书 `isPageMode=true`，模式切换按钮弹出提示
- **测试**: 21 条测试全部通过（model_test / epub_service_test / reader_screen_test / widget_test）

---

## 2026-06-29 重构记录

### 分页算法参数化 + 死代码清理
- **问题**: `reader_content_area.dart`（273行）为未完成的组件抽取，与 `reader_screen.dart` 的分页逻辑完全重复但从未被引用
- **处理**: 
  - 删除 `reader_content_area.dart`
  - `_splitIntoPages` / `_lineEndOffset` 改为显式参数传递（原依赖 Widget 实例变量 `_screenWidth` 等），分页算法变为纯函数，可独立测试
  - `_buildContent` 的三层兜底逻辑（空内容→章节标题→"[图片页]"、短内容不用 ScrollView）保留不变
- **附带修复**: 
  - 测试中 `Book.isPageMode` 默认值从 `false` 同步为 `true`（2 处）
  - TODO #1（字体缩放分页）通过 `onFontSizeChanged` 回调修复
  - TODO #3（翻页区域过大）zoneWidth `/3` → `/5`

### HTML 工具抽取 + 换行符归一化
- **问题**: `_stripHtml` / `_decodeHtmlEntities` 在 `reader_screen.dart` 和 `epub_service.dart` 中各有一份重复实现（共 3 处）
- **处理**:
  - 创建 `lib/utils/html_utils.dart`，提供 `stripHtml()` 和 `decodeHtmlEntities()` 两个公共函数
  - `reader_screen.dart` 删除私有 `_stripHtml`（~40行），改为 import utils
  - `epub_service.dart` 删除私有 `_stripHtml` 和 `_decodeHtmlEntities`（~60行），改为 import utils
  - `stripHtml` 中新增 `\r\n` → `\n` 和 `\r` → `\n` 换行符归一化 → 修复 TODO #2

### 进度快照系统（新增）
- **动机**: library.json 序列化链路长（state → book → _books → toJson → 文件 → fromJson → init → _recalculatePages），fire-and-forget 保存与退出保存存在竞态，导致 currentPage 始终为 0
- **实现**:
  - `EpubService`: `saveProgressSnapshot` / `loadProgressSnapshot` / `deleteProgressSnapshot`
  - 退出时 `_persistProgressAndFlush` 写入独立快照文件 `snapshot_${bookId}.json`
  - 进入时 `init` 先同步设置 book 默认值，再异步加载快照覆盖
  - 删除书籍时清理快照文件
- **已知问题**: ✅ 已修复 — `_loadSnapshot` 保持异步（不阻塞首次渲染），完成后通过 `ref.listen` 触发 `_recalculatePages` 重算（`reader_screen.dart` build 中监听 `currentChapterIndex` 变化）

### 进度条优化
- 翻页模式显示 `页码/总页数`（如 "3/10"），滚动模式保持百分比
- 新增 `ReaderNotifier.progressIndicator` getter

### 本次已修复
| # | 描述 | 状态 |
|---|------|:----:|
| 1 | 字体缩放后分页未重算 | ✅ |
| 2 | 特殊段落排版异常（CRLF） | ✅ |
| 3 | 翻页区域过大 | ✅ |
| — | 书签重复添加 | ✅ |
| — | SnackBar 居中 + 淡色 | ✅ |
| — | 删除书签即时刷新 | ✅ |
| 10 | 旧数据兼容 | ✅ |
| 12 | 封面 fallback | ✅ |
| — | **翻页进度保存/恢复**（快照覆盖后 `ref.listen` 触发 `_recalculatePages`） | ✅ |

### 遗留问题
| # | 描述 | 优先级 |
|---|------|:----:|
| — | 字体缩放后进度漂移（比例恢复逻辑已回退为简单 clamp） | 中 |
| 9 | EPUB 图片显示 | 中 |
| 11 | 滚动模式残留代码 | 低 |
