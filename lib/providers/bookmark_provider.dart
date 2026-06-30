import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../services/epub_service.dart';

/// 书签状态
class BookmarkState {
  final List<Bookmark> bookmarks;
  final bool isLoading;
  final String bookId;

  const BookmarkState({
    this.bookmarks = const [],
    this.isLoading = false,
    this.bookId = '',
  });

  BookmarkState copyWith({
    List<Bookmark>? bookmarks,
    bool? isLoading,
    String? bookId,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
      bookId: bookId ?? this.bookId,
    );
  }
}

class BookmarkNotifier extends Notifier<BookmarkState> {
  late final EpubService _epubService;
  final _uuid = const Uuid();

  @override
  BookmarkState build() {
    _epubService = EpubService();
    return const BookmarkState();
  }

  /// 初始化：加载指定书籍的书签
  Future<void> init(String bookId) async {
    state = state.copyWith(bookId: bookId, isLoading: true);
    final bookmarks = await _epubService.getBookmarks(bookId);
    state = state.copyWith(bookmarks: bookmarks, isLoading: false);
  }

  /// 添加书签
  Future<void> addBookmark({
    required int chapterIndex,
    required String chapterTitle,
    required double progressInChapter,
    required String textSnippet,
  }) async {
    final bookmark = Bookmark(
      id: _uuid.v4(),
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      progressInChapter: progressInChapter,
      textSnippet: textSnippet,
      createdAt: DateTime.now(),
    );

    await _epubService.addBookmark(state.bookId, bookmark);
    state = state.copyWith(bookmarks: [...state.bookmarks, bookmark]);
    developer.log('[BookmarkNotifier] added bookmark at ch=$chapterIndex');
  }

  /// 删除书签
  Future<void> removeBookmark(String bookmarkId) async {
    await _epubService.removeBookmark(state.bookId, bookmarkId);
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );
    developer.log('[BookmarkNotifier] removed bookmark $bookmarkId');
  }
}
