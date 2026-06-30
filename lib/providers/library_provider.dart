import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/epub_service.dart';

/// 书架状态
class LibraryState {
  final List<Book> books;
  final bool isLoading;

  const LibraryState({
    this.books = const [],
    this.isLoading = false,
  });

  LibraryState copyWith({List<Book>? books, bool? isLoading}) {
    return LibraryState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  late final EpubService _epubService;

  @override
  LibraryState build() {
    _epubService = EpubService();
    // build() 期间 state 未就绪，用 microtask 延迟异步加载
    Future.microtask(() => _loadBooks());
    return const LibraryState(isLoading: true);
  }

  Future<void> _loadBooks() async {
    state = state.copyWith(isLoading: true);
    try {
      await _epubService.loadLibrary();
    } catch (e) {
      developer.log('Failed to load library in _loadBooks: $e');
    }
    state = state.copyWith(
      books: _epubService.books,
      isLoading: false,
    );
  }

  Future<void> refreshBooks() => _loadBooks();

  Future<void> importBook({
    required String filePath,
    required Uint8List? fileBytes,
    required String? fileName,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _epubService.importBook(
        filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      await _loadBooks();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      developer.log('Failed to import book: $e');
      rethrow;
    }
  }

  Future<void> removeBook(String bookId) async {
    await _epubService.removeBook(bookId);
    await _loadBooks();
  }
}
