import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/epub_service.dart';

/// 阅读器核心业务状态（非 UI 状态）
class ReaderState {
  final Book book;
  final int currentChapterIndex;
  final double fontSize;
  final bool isDarkMode;
  final bool isPageMode;
  final int currentPage;
  final List<String> pages;
  /// 滚动模式下的章节内进度 (0.0 ~ 1.0)
  final double scrollProgressInChapter;

  const ReaderState({
    required this.book,
    this.currentChapterIndex = 0,
    this.fontSize = 18.0,
    this.isDarkMode = false,
    this.isPageMode = false,
    this.currentPage = 0,
    this.pages = const [],
    this.scrollProgressInChapter = 0.0,
  });

  ReaderState copyWith({
    Book? book,
    int? currentChapterIndex,
    double? fontSize,
    bool? isDarkMode,
    bool? isPageMode,
    int? currentPage,
    List<String>? pages,
    double? scrollProgressInChapter,
  }) {
    return ReaderState(
      book: book ?? this.book,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      fontSize: fontSize ?? this.fontSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isPageMode: isPageMode ?? this.isPageMode,
      currentPage: currentPage ?? this.currentPage,
      pages: pages ?? this.pages,
      scrollProgressInChapter: scrollProgressInChapter ?? this.scrollProgressInChapter,
    );
  }
}

/// 阅读器状态管理
class ReaderNotifier extends Notifier<ReaderState> {
  late final EpubService _epubService;

  @override
  ReaderState build() {
    _epubService = EpubService();
    // 返回占位状态，真正的初始化在 init() 中完成
    return ReaderState(
      book: Book(id: '', title: '', filePath: ''),
    );
  }

  /// 用指定书籍初始化（在进入阅读器时调用）。
  /// 先同步设置基于 book 的基础状态，再异步加载快照覆盖。
  /// 快照覆盖后 state 会变化，由 reader_screen 通过 ref.listen 触发重算。
  void init(Book book) {
    state = ReaderState(
      book: book,
      currentChapterIndex: book.currentChapterIndex,
      isDarkMode: book.isDarkMode,
      isPageMode: true,
      currentPage: book.currentPage,
    );

    // 异步加载快照，完成后 state 变化会由 UI 层监听并触发分页重算
    _loadSnapshot(book.id);
  }

  Future<void> _loadSnapshot(String bookId) async {
    try {
      final snapshot = await _epubService.loadProgressSnapshot(bookId);
      if (snapshot == null) return;
      state = state.copyWith(
        currentChapterIndex: snapshot.chapterIndex,
        currentPage: snapshot.page,
      );
    } catch (_) {
      // 快照文件不可用，保持 book 中的值
    }
  }

  /// 保存进度到持久化存储（fire-and-forget，适用于翻页等高频操作）
  void _persistProgress() {
    if (state.book.chapters.isEmpty) return;
    final progress = state.currentChapterIndex /
        (state.book.chapters.length - 1).clamp(1, double.infinity);
    // 同步 state.book 对象（内存操作，即刻生效）
    state.book.currentChapterIndex = state.currentChapterIndex;
    state.book.progress = progress;
    state.book.isPageMode = state.isPageMode;
    state.book.currentPage = state.currentPage;
    state.book.scrollOffset = state.scrollProgressInChapter;
    state.book.isDarkMode = state.isDarkMode;
    // 异步写盘（翻页时无需等待）
    _epubService.updateProgress(
      state.book.id,
      state.currentChapterIndex,
      progress,
      isPageMode: state.isPageMode,
      currentPage: state.currentPage,
      scrollOffset: state.scrollProgressInChapter,
      isDarkMode: state.isDarkMode,
    );
  }

  /// 同 _persistProgress，但确保 library.json 和快照文件均写入完成后返回
  Future<void> _persistProgressAndFlush() async {
    if (state.book.chapters.isEmpty) return;
    final progress = state.currentChapterIndex /
        (state.book.chapters.length - 1).clamp(1, double.infinity);
    state.book.currentChapterIndex = state.currentChapterIndex;
    state.book.progress = progress;
    state.book.isPageMode = state.isPageMode;
    state.book.currentPage = state.currentPage;
    state.book.scrollOffset = state.scrollProgressInChapter;
    state.book.isDarkMode = state.isDarkMode;
    await _epubService.updateProgress(
      state.book.id,
      state.currentChapterIndex,
      progress,
      isPageMode: state.isPageMode,
      currentPage: state.currentPage,
      scrollOffset: state.scrollProgressInChapter,
      isDarkMode: state.isDarkMode,
    );
    // 独立进度快照——短链路，退出时写入、进入时直接读取
    await _epubService.saveProgressSnapshot(
      state.book.id,
      state.currentChapterIndex,
      state.currentPage,
    );
  }

  // ─── 章节导航 ───

  void nextChapter() {
    if (state.currentChapterIndex < state.book.chapters.length - 1) {
      state = state.copyWith(
        currentChapterIndex: state.currentChapterIndex + 1,
        currentPage: 0,
        scrollProgressInChapter: 0.0,
      );
      developer.log('[ReaderNotifier] nextChapter -> ${state.currentChapterIndex}');
      _persistProgress();
    }
  }

  void previousChapter() {
    if (state.currentChapterIndex > 0) {
      state = state.copyWith(
        currentChapterIndex: state.currentChapterIndex - 1,
        scrollProgressInChapter: 0.0,
      );
      developer.log('[ReaderNotifier] prevChapter -> ${state.currentChapterIndex}');
      _persistProgress();
    }
  }

  void jumpToChapter(int index) {
    if (index == state.currentChapterIndex || index < 0 || index >= state.book.chapters.length) return;
    state = state.copyWith(
      currentChapterIndex: index,
      currentPage: 0,
      scrollProgressInChapter: 0.0,
    );
    developer.log('[ReaderNotifier] jumpToChapter -> $index');
    _persistProgress();
  }

  // ─── 翻页模式 ───

  void nextPage() {
    if (!state.isPageMode) return;
    if (state.currentPage < state.pages.length - 1) {
      state = state.copyWith(currentPage: state.currentPage + 1);
      developer.log('[ReaderNotifier] nextPage -> ${state.currentPage}/${state.pages.length}');
      _persistProgress();
    } else {
      nextChapter();
    }
  }

  void previousPage() {
    if (!state.isPageMode) return;
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
      developer.log('[ReaderNotifier] prevPage -> ${state.currentPage}/${state.pages.length}');
      _persistProgress();
    } else {
      previousChapter();
    }
  }

  // ─── 模式与偏好 ───

  void togglePageMode() {
    state = state.copyWith(isPageMode: !state.isPageMode);
    developer.log('[ReaderNotifier] isPageMode -> ${state.isPageMode}');
    _persistProgress();
  }

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
    developer.log('[ReaderNotifier] isDarkMode -> ${state.isDarkMode}');
    _persistProgress();
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(12.0, 36.0));
    developer.log('[ReaderNotifier] fontSize -> ${state.fontSize}');
  }

  void setPages(List<String> pages) {
    state = state.copyWith(pages: pages);
  }

  void setCurrentPage(int page) {
    if (page >= 0 && page < state.pages.length) {
      state = state.copyWith(currentPage: page);
    }
  }

  void setScrollProgress(double progress) {
    state = state.copyWith(scrollProgressInChapter: progress.clamp(0.0, 1.0));
  }

  /// 退出阅读器前调用，等待 library.json + 快照文件均落盘后返回
  Future<void> onExit() async {
    await _persistProgressAndFlush();
  }

  /// 进度指示文本：翻页模式显示 "3/10"，滚动模式显示百分比
  String get progressIndicator {
    if (state.book.chapters.isEmpty) return '0/0';
    if (state.isPageMode) {
      return state.pages.isEmpty
          ? '0/0'
          : '${state.currentPage + 1}/${state.pages.length}';
    }
    return progressPercent;
  }

  /// 计算当前全局进度百分比
  String get progressPercent {
    if (state.book.chapters.isEmpty) return '0.00%';
    final double pct;
    if (state.isPageMode) {
      pct = state.pages.isEmpty
          ? 0.0
          : (state.currentPage + 1) / state.pages.length * 100;
    } else {
      final chapterBase = state.currentChapterIndex / state.book.chapters.length;
      final inChapter = state.scrollProgressInChapter / state.book.chapters.length;
      pct = (chapterBase + inChapter) * 100;
    }
    return '${pct.toStringAsFixed(2)}%';
  }
}
