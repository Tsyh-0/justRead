import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/reader_provider.dart';
import '../widgets/reader_top_bar.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/font_size_dialog.dart';
import '../widgets/toc_sheet.dart';
import '../widgets/bookmark_sheet.dart';
import '../providers/bookmark_provider.dart';
import '../utils/html_utils.dart';

final readerProvider = NotifierProvider<ReaderNotifier, ReaderState>(
  ReaderNotifier.new,
);

final bookmarkProvider =
    NotifierProvider<BookmarkNotifier, BookmarkState>(BookmarkNotifier.new);

class ReaderScreen extends ConsumerStatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  // 阅读区域额外垂直边距
  static const double _extraTopPadding = 12;
  static const double _extraBottomPadding = 12;

  // UI-only state (not in provider)
  bool _showControls = false;
  Timer? _autoHideTimer;
  final ScrollController _scrollController = ScrollController();

  // 屏幕布局信息
  double _screenWidth = 360;
  double _screenHeight = 640;
  double _topSafeArea = 0;
  double _bottomSafeArea = 0;

  // 模式切换暂存
  double _pendingScrollProgress = -1.0;

  bool _didInitialRecalc = false;
  /// 上次分页重算时的 chapterIndex，用于 ref.listen 防循环
  int _lastRecalcChapterIndex = -1;
  /// PopScope 防重入：进度保存完成后允许 pop
  bool _shouldAllowPop = false;

  @override
  void initState() {
    super.initState();

    final book = widget.book;

    developer.log('[ReaderScreen] init book="${book.title}" '
        'chIdx=${book.currentChapterIndex} isPageMode=${book.isPageMode}');

    // 滚动监听
    _scrollController.addListener(_onScroll);

    // 延迟初始化 provider（Riverpod 禁止在 build 阶段修改 state）
    Future.microtask(() {
      if (!mounted) return;
      ref.read(readerProvider.notifier).init(book);
      ref.read(bookmarkProvider.notifier).init(book.id);
      // init 完成后触发首次分页和滚动恢复（快照将在后台加载，完成后由 ref.listen 触发重算）
      _recalculatePages();
      _restoreScrollPosition();
    });
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final notifier = ref.read(readerProvider.notifier);
    final state = ref.read(readerProvider);
    if (state.isPageMode) return; // 翻页模式不管滚动
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0) {
      final progress =
          (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
      notifier.setScrollProgress(progress);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _topSafeArea = mediaQuery.padding.top;
    _bottomSafeArea = mediaQuery.padding.bottom;
    // 重算和恢复滚动已移至 microtask（避免 build 期间修改 provider）
  }

  @override
  void dispose() {
    // 进度保存已移至 PopScope.onPopInvokedWithResult 统一处理
    _autoHideTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ─── 控件显示/隐藏 ───

  void _toggleControls() {
    developer.log('[toggleControls] from=$_showControls to=${!_showControls}');
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _scheduleAutoHide();
      } else {
        _autoHideTimer?.cancel();
      }
    });
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        _toggleControls();
      }
    });
  }

  // ─── 分页 ───

  void _recalculatePages() {
    final state = ref.read(readerProvider);
    if (state.book.chapters.isEmpty) return;
    final chapter = state.book.chapters[state.currentChapterIndex];
    final text = stripHtml(chapter.contentHtml);

    final pages = _splitIntoPages(
      text,
      state.fontSize,
      _screenWidth,
      _screenHeight,
      _topSafeArea,
      _bottomSafeArea,
    );
    ref.read(readerProvider.notifier).setPages(pages);

    final restoredPage = state.currentPage.clamp(0, pages.length - 1);
    if (restoredPage != state.currentPage) {
      ref.read(readerProvider.notifier).setCurrentPage(restoredPage);
    }
    _lastRecalcChapterIndex = state.currentChapterIndex;
    developer.log('[recalcPages] pages=${pages.length}');
  }

  List<String> _splitIntoPages(
    String text,
    double fontSize,
    double screenWidth,
    double screenHeight,
    double topSafeArea,
    double bottomSafeArea,
  ) {
    if (text.isEmpty) return [''];

    final textStyle = TextStyle(fontSize: fontSize, height: 1.8);
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final double usableWidth = screenWidth - 40;
    final double usableHeight = screenHeight -
        (topSafeArea + _extraTopPadding) -
        (_bottomSafeArea + 16 + _extraBottomPadding);

    painter.layout(maxWidth: usableWidth);
    if (usableHeight <= 0 || painter.height <= 0) return [text];

    final lineMetrics = painter.computeLineMetrics();
    if (lineMetrics.isEmpty) return [text];

    final pages = <String>[];
    int pageStartLine = 0;
    double pageHeight = 0;

    for (int i = 0; i < lineMetrics.length; i++) {
      final line = lineMetrics[i];
      if (pageHeight + line.height > usableHeight && pageHeight > 0) {
        final start = _lineStartOffset(painter, lineMetrics, pageStartLine);
        final end = _lineEndOffset(painter, lineMetrics, i - 1, screenWidth);
        pages.add(text.substring(start, end));
        pageStartLine = i;
        pageHeight = line.height;
      } else {
        pageHeight += line.height;
      }
    }

    if (pageStartLine < lineMetrics.length) {
      final start = _lineStartOffset(painter, lineMetrics, pageStartLine);
      pages.add(text.substring(start));
    }

    if (pages.isEmpty) pages.add(text);
    return pages;
  }

  int _lineStartOffset(
      TextPainter painter, List<LineMetrics> metrics, int lineIndex) {
    final line = metrics[lineIndex];
    final y = line.baseline - line.ascent + 1;
    return painter.getPositionForOffset(Offset(0, y)).offset;
  }

  int _lineEndOffset(
      TextPainter painter, List<LineMetrics> metrics, int lineIndex,
      double screenWidth) {
    if (lineIndex + 1 < metrics.length) {
      return _lineStartOffset(painter, metrics, lineIndex + 1);
    }
    final line = metrics[lineIndex];
    final y = line.baseline + line.descent;
    return painter
        .getPositionForOffset(
            Offset(screenWidth - 40, y.clamp(0, painter.height)))
        .offset;
  }

  // ─── 恢复滚动位置 ───

  void _restoreScrollPosition() {
    final state = ref.read(readerProvider);
    if (state.isPageMode) return;
    final savedOffset = widget.book.scrollOffset;
    if (savedOffset > 0 && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          if (maxExtent > 0) {
            _scrollController.jumpTo(savedOffset.clamp(0.0, maxExtent));
          }
        }
      });
    }
  }

  // ─── 手势分发 ───

  void _handleTap(TapUpDetails details) {
    if (_showControls) {
      _toggleControls();
      return;
    }
    final width = _screenWidth;
    final zoneWidth = width / 5;
    final dx = details.localPosition.dx;
    if (dx < zoneWidth) {
      _onLeftTap();
    } else if (dx > width - zoneWidth) {
      _onRightTap();
    } else {
      _toggleControls();
    }
  }

  void _onLeftTap() {
    final notifier = ref.read(readerProvider.notifier);
    final state = ref.read(readerProvider);
    if (!state.isPageMode) { if (!_showControls) _toggleControls(); return; }
    if (state.currentPage > 0) {
      notifier.setCurrentPage(state.currentPage - 1);
    } else if (state.currentChapterIndex > 0) {
      notifier.jumpToChapter(state.currentChapterIndex - 1);
      _recalculatePages();
      final newState = ref.read(readerProvider);
      if (newState.pages.isNotEmpty) {
        notifier.setCurrentPage(newState.pages.length - 1);
      }
    }
  }

  void _onRightTap() {
    final notifier = ref.read(readerProvider.notifier);
    final state = ref.read(readerProvider);
    if (!state.isPageMode) { if (!_showControls) _toggleControls(); return; }
    if (state.currentPage < state.pages.length - 1) {
      notifier.setCurrentPage(state.currentPage + 1);
    } else if (state.currentChapterIndex < state.book.chapters.length - 1) {
      notifier.jumpToChapter(state.currentChapterIndex + 1);
      _recalculatePages();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final state = ref.read(readerProvider);
    if (!state.isPageMode) return;
    final velocity = details.velocity;
    final vx = velocity.pixelsPerSecond.dx.abs();
    final vy = velocity.pixelsPerSecond.dy.abs();
    if (vx < vy * 2 || vx < 300) return;
    if (velocity.pixelsPerSecond.dx > 0) {
      _onLeftTap();
    } else {
      _onRightTap();
    }
  }

  // ─── 目录 ───

  void _showTableOfContents() {
    final state = ref.read(readerProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => TocSheet(
        state: state,
        screenHeight: _screenHeight,
        onJump: (index) {
          ref.read(readerProvider.notifier).jumpToChapter(index);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _recalculatePages();
            }
          });
          if (!state.isPageMode && _scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.jumpTo(0);
            });
          }
        },
      ),
    );
  }

  // ─── 字号对话框 ───

  void _showFontSizeDialog() {
    final currentSize = ref.read(readerProvider).fontSize;
    showDialog(
      context: context,
      builder: (ctx) => FontSizeDialog(
        currentSize: currentSize,
        onChanged: (size) {
          ref.read(readerProvider.notifier).setFontSize(size);
          _recalculatePages();
        },
      ),
    );
  }

  // ─── 书签 ───

  void _addBookmark() {
    final state = ref.read(readerProvider);
    if (state.book.chapters.isEmpty) return;

    // 去重：检查当前位置是否已有书签（同章 + 进度差 < 2%）
    final bmState = ref.read(bookmarkProvider);
    final progressInChapter = state.isPageMode
        ? (state.pages.isNotEmpty ? state.currentPage / state.pages.length : 0.0)
        : state.scrollProgressInChapter;

    final alreadyExists = bmState.bookmarks.any((b) =>
        b.chapterIndex == state.currentChapterIndex &&
        (b.progressInChapter - progressInChapter).abs() < 0.02);

    if (alreadyExists) {
      _showToast('此处已有书签');
      return;
    }

    final chapter = state.book.chapters[state.currentChapterIndex];
    final plainText = stripHtml(chapter.contentHtml);
    // 截取当前章节前50字作为摘要
    final snippet = plainText.length > 50 ? '${plainText.substring(0, 50)}...' : plainText;

    ref.read(bookmarkProvider.notifier).addBookmark(
      chapterIndex: state.currentChapterIndex,
      chapterTitle: chapter.title,
      progressInChapter: progressInChapter,
      textSnippet: snippet,
    );

    _showToast('书签已添加');
  }

  void _showBookmarks() {
    final state = ref.read(readerProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentBookmarks = ref.read(bookmarkProvider).bookmarks;
          return BookmarkSheet(
            bookmarks: currentBookmarks,
            isDarkMode: state.isDarkMode,
            onJump: (bookmark) {
              final notifier = ref.read(readerProvider.notifier);
              notifier.jumpToChapter(bookmark.chapterIndex);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _recalculatePages();
                  if (!state.isPageMode && _scrollController.hasClients) {
                    final maxExtent = _scrollController.position.maxScrollExtent;
                    if (maxExtent > 0) {
                      _scrollController.jumpTo(
                          (bookmark.progressInChapter * maxExtent)
                              .clamp(0.0, maxExtent));
                    }
                  } else if (state.isPageMode &&
                      ref.read(readerProvider).pages.isNotEmpty) {
                    final pages = ref.read(readerProvider).pages;
                    final page = (bookmark.progressInChapter * (pages.length - 1))
                        .round()
                        .clamp(0, pages.length - 1);
                    notifier.setCurrentPage(page);
                  }
                }
              });
            },
            onDelete: (id) {
              ref.read(bookmarkProvider.notifier).removeBookmark(id);
              setSheetState(() {}); // 即时刷新书签列表
            },
          );
        },
      ),
    );
  }

  // ─── 模式切换 ───

  void _handleModeToggle() {
    _showToast('EPUB 格式仅支持翻页模式');
  }

  /// 屏幕中央半透明 toast，不遮挡底部菜单栏。
  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.2,
          vertical: MediaQuery.of(context).size.height * 0.42,
        ),
        backgroundColor: Colors.black54,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── build ───

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerProvider);
    final notifier = ref.read(readerProvider.notifier);

    // 监听快照覆盖：当异步加载的快照改变了 currentChapterIndex 时，触发分页重算
    ref.listen(readerProvider, (prev, next) {
      if (prev != null &&
          prev.currentChapterIndex != next.currentChapterIndex &&
          next.currentChapterIndex != _lastRecalcChapterIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recalculatePages();
        });
      }
    });

    return PopScope(
      canPop: _shouldAllowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _shouldAllowPop) return;
        // 统一拦截所有退出路径（系统返回键 / 手势 / TopBar 返回键），确保进度先落盘
        await ref.read(readerProvider.notifier).onExit();
        if (!mounted) return;
        setState(() => _shouldAllowPop = true);
        // 下一帧 canPop 生效后自动 pop（避免递归触发 onPopInvokedWithResult）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      },
      child: Scaffold(
        backgroundColor:
            state.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F0E8),
        body: Stack(
          children: [
            // 底层：内容区域 + 底部栏
            Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapUp: _handleTap,
                    onPanEnd: state.isPageMode ? _handleDragEnd : null,
                    behavior: HitTestBehavior.translucent,
                    child: _buildContent(state),
                  ),
                ),
                // 底部栏
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: _showControls
                      ? ReaderBottomBar(
                          state: state,
                          notifier: notifier,
                          onShowToc: _showTableOfContents,
                          onShowFontDialog: _showFontSizeDialog,
                          onFontSizeChanged: _recalculatePages,
                          onAddBookmark: _addBookmark,
                          onShowBookmarks: _showBookmarks,
                          onToggleMode: _handleModeToggle,
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),
              ],
            ),
            // 顶层：顶部栏（浮在状态栏上方，不挤压内容）
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1.0 : 0.0,
              alwaysIncludeSemantics: false,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: ReaderTopBar(
                  state: state,
                  onBack: () {
                    Navigator.pop(context); // PopScope 统一处理进度保存
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ReaderState state) {
    developer.log('[buildContent] chIdx=${state.currentChapterIndex} '
        'isPageMode=${state.isPageMode} pages=${state.pages.length}');
    if (state.book.chapters.isEmpty) {
      return Center(
        child: Text(
          '无法解析章节内容',
          style: TextStyle(
            fontSize: state.fontSize,
            color: state.isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      );
    }

    String displayText;
    if (state.isPageMode) {
      if (state.pages.isEmpty) {
        displayText = state.book.chapters[state.currentChapterIndex].title;
      } else {
        displayText = state.currentPage < state.pages.length
            ? state.pages[state.currentPage]
            : '';
      }
    } else {
      final chapter = state.book.chapters[state.currentChapterIndex];
      displayText = stripHtml(chapter.contentHtml);
    }
    // 封面等纯图片页面 strip 后为空，用章节标题占位
    if (displayText.trim().isEmpty) {
      displayText = state.book.chapters[state.currentChapterIndex].title;
    }
    // 终极兜底：章节标题也可能为空
    if (displayText.trim().isEmpty) {
      displayText = '[图片页]';
    }

    final textStyle = TextStyle(
      fontSize: state.fontSize,
      height: 1.8,
      color: state.isDarkMode ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
    );

    if (state.isPageMode) {
      return _buildPageMode(displayText, textStyle);
    }
    // 内容太短无需滚动时，不用 ScrollView，避免手势被消费
    final usableHeight = _screenHeight - _topSafeArea - _bottomSafeArea - 60;
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _screenWidth - 40);
    if (painter.height < usableHeight) {
      return _buildStaticContent(displayText, textStyle);
    }
    return _buildScrollMode(displayText, textStyle);
  }

  Widget _buildPageMode(String text, TextStyle style) {
    final display = text.isEmpty ? '　' : text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ref.read(readerProvider).isDarkMode
                ? Colors.white24
                : Colors.black12,
            width: 0.5,
          ),
          bottom: BorderSide(
            color: ref.read(readerProvider).isDarkMode
                ? Colors.white24
                : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: _topSafeArea + _extraTopPadding,
        bottom: _bottomSafeArea + 28,
      ),
      child: Text(display, style: style),
    );
  }

  Widget _buildScrollMode(String text, TextStyle style) {
    final isDark = ref.read(readerProvider).isDarkMode;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 0.5,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: _topSafeArea + _extraTopPadding,
          bottom: _bottomSafeArea + 28,
        ),
        child: Text(text, style: style),
      ),
    );
  }

  /// 内容短到无需滚动时使用，避免 ScrollView 消费手势
  Widget _buildStaticContent(String text, TextStyle style) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ref.read(readerProvider).isDarkMode ? Colors.white24 : Colors.black12,
            width: 0.5,
          ),
          bottom: BorderSide(
            color: ref.read(readerProvider).isDarkMode ? Colors.white24 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: _topSafeArea + _extraTopPadding,
        bottom: _bottomSafeArea + 28,
      ),
      child: Text(text, style: style),
    );
  }
}