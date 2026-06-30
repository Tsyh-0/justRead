import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/book.dart';
import '../utils/html_utils.dart';

class EpubService {
  static final EpubService _instance = EpubService._internal();
  factory EpubService() => _instance;
  EpubService._internal();

  List<Book> _books = [];
  List<Book> get books => List.unmodifiable(_books);

  /// Generate a stable unique ID for a book based on file name and content hash.
  /// Uses base64 of a content sample — deterministic, stable across runs.
  String _generateBookId(String fileName, Uint8List bytes) {
    final prefix = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final contentSample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    final hash = base64Encode(contentSample)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, 20);
    return '${prefix}_$hash';
  }

  /// Parse an EPUB file from bytes and return a Book object
  Future<Book> parseEpubBytes(Uint8List bytes, String fileName, {String? filePath}) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);

      final bookId = _generateBookId(fileName, bytes);

      // Extract cover image with multiple fallback strategies
      Uint8List? coverData;
      try {
        // Strategy 1: Use epubBook.CoverImage (Image from package:image)
        final coverImage = epubBook.CoverImage;
        if (coverImage != null) {
          final imageBytes = coverImage.getBytes();
          if (imageBytes.isNotEmpty) {
            coverData = Uint8List.fromList(imageBytes);
          }
        }
      } catch (e) {
        developer.log('Failed to extract cover image (strategy 1): $e');
      }

      // Strategy 2: Look for cover reference in manifest metadata
      if (coverData == null && epubBook.Schema?.Package?.Manifest?.Items != null) {
        try {
          final items = epubBook.Schema!.Package!.Manifest!.Items!;
          // Find the cover item by common IDs
          EpubManifestItem? coverItem;
          for (final item in items) {
            if (item.Id != null && item.Id!.toLowerCase().contains('cover')) {
              coverItem = item;
              break;
            }
          }
          if (coverItem != null && coverItem.Href != null) {
            final href = coverItem.Href!;
            // Try to find the image in Content.Images
            if (epubBook.Content?.Images != null) {
              for (final imgEntry in epubBook.Content!.Images!.entries) {
                if (imgEntry.key.contains(href.split('/').last) ||
                    (coverItem.Id != null && imgEntry.key.contains(coverItem.Id!))) {
                  final imgContent = imgEntry.value.Content;
                  if (imgContent != null && imgContent.isNotEmpty) {
                    coverData = Uint8List.fromList(imgContent);
                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          developer.log('Failed to extract cover image (strategy 2): $e');
        }
      }

      // Strategy 3: Use the first image from Content.Images as fallback
      if (coverData == null && epubBook.Content?.Images != null && epubBook.Content!.Images!.isNotEmpty) {
        try {
          final firstImage = epubBook.Content!.Images!.entries.first;
          final imgContent = firstImage.value.Content;
          if (imgContent != null && imgContent.isNotEmpty) {
            coverData = Uint8List.fromList(imgContent);
            developer.log('Using first image as cover: ${firstImage.key}');
          }
        } catch (e) {
          developer.log('Failed to extract cover image (strategy 3): $e');
        }
      }

      // Build a map of all HTML content files by their href (file name)
      final Map<String, String> htmlContentMap = {};
      if (epubBook.Content?.Html != null) {
        for (final entry in epubBook.Content!.Html!.entries) {
          final content = entry.value.Content ?? '';
          if (content.isNotEmpty) {
            htmlContentMap[entry.key] = content;
          }
        }
      }

      // Extract chapters: recursively traverse EpubChapter tree to collect all content
      final chapters = <Chapter>[];
      if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
        for (final chapter in epubBook.Chapters!) {
          _collectChaptersRecursive(chapter, htmlContentMap, chapters);
        }
      }

      // If still no chapters, try building from spine (reading order)
      if (chapters.isEmpty) {
        final spineChapters = _buildChaptersFromSpine(epubBook, htmlContentMap);
        if (spineChapters.isNotEmpty) {
          chapters.addAll(spineChapters);
          developer.log('Built ${spineChapters.length} chapters from spine order');
        }
      }

      // Last resort: fall back to all HTML content files
      if (chapters.isEmpty && htmlContentMap.isNotEmpty) {
        for (final entry in htmlContentMap.entries) {
          chapters.add(Chapter(
            title: _extractTitleFromHtml(entry.value),
            contentHtml: entry.value,
            href: entry.key,
          ));
        }
      }

      developer.log('Parsed ${chapters.length} chapters from EPUB: ${epubBook.Title}');

      final book = Book(
        id: bookId,
        title: epubBook.Title ?? _extractTitleFromFileName(fileName),
        author: epubBook.Author ?? 'Unknown Author',
        coverData: coverData,
        filePath: filePath ?? '',
        chapters: chapters,
      );

      // Save cover image to app directory
      if (coverData != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final coverDir = Directory('${appDir.path}/covers');
          if (!await coverDir.exists()) {
            await coverDir.create(recursive: true);
          }
          final coverFile = File('${coverDir.path}/${book.id}.jpg');
          await coverFile.writeAsBytes(coverData);
        } catch (e) {
          developer.log('Failed to save cover image: $e');
        }
      }

      return book;
    } catch (e, stackTrace) {
      developer.log('Failed to parse EPUB file: $e\n$stackTrace');
      // Return a minimal book with error info instead of crashing
      final bookId = _generateBookId(fileName, bytes);
      return Book(
        id: bookId,
        title: _extractTitleFromFileName(fileName),
        author: 'Unknown Author',
        filePath: filePath ?? '',
        chapters: [
          Chapter(
            title: '解析失败',
            contentHtml: '<p>无法解析此 EPUB 文件。文件可能已损坏或使用了不兼容的格式。</p><p>错误信息：$e</p>',
          ),
        ],
      );
    }
  }

  /// Recursively collect chapters from EpubChapter tree.
  void _collectChaptersRecursive(
    EpubChapter chapter,
    Map<String, String> htmlContentMap,
    List<Chapter> result,
  ) {
    String ownContent = chapter.HtmlContent ?? '';
    final href = chapter.ContentFileName;

    if (ownContent.isEmpty && href != null && href.isNotEmpty) {
      ownContent = _lookupHtmlContent(href, htmlContentMap);
    }

    final hasSubChapters =
        chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty;

    if (hasSubChapters) {
      if (ownContent.isNotEmpty) {
        result.add(Chapter(
          title: chapter.Title ?? _extractTitleFromHtml(ownContent),
          contentHtml: ownContent,
          href: href,
        ));
      }
      for (final sub in chapter.SubChapters!) {
        _collectChaptersRecursive(sub, htmlContentMap, result);
      }
    } else {
      if (ownContent.isNotEmpty) {
        result.add(Chapter(
          title: chapter.Title ?? _extractTitleFromHtml(ownContent),
          contentHtml: ownContent,
          href: href,
        ));
      }
    }
  }

  /// Build chapters from EPUB spine (reading order) when TOC is incomplete
  List<Chapter> _buildChaptersFromSpine(
    EpubBook epubBook,
    Map<String, String> htmlContentMap,
  ) {
    final chapters = <Chapter>[];
    try {
      final spine = epubBook.Schema?.Package?.Spine;
      if (spine == null || spine.Items == null || spine.Items!.isEmpty) {
        return chapters;
      }

      final manifest = epubBook.Schema?.Package?.Manifest?.Items;
      if (manifest == null || manifest.isEmpty) {
        return chapters;
      }

      for (final spineItem in spine.Items!) {
        final idref = spineItem.IdRef;
        if (idref == null || idref.isEmpty) continue;

        EpubManifestItem? manifestItem;
        for (final item in manifest) {
          if (item.Id == idref) {
            manifestItem = item;
            break;
          }
        }
        if (manifestItem == null) {
          for (final item in manifest) {
            if (item.Id != null && item.Id!.toLowerCase() == idref.toLowerCase()) {
              manifestItem = item;
              break;
            }
          }
        }
        if (manifestItem == null) continue;

        final href = manifestItem.Href;
        if (href == null || href.isEmpty) continue;

        final content = _lookupHtmlContent(href, htmlContentMap);
        if (content.isEmpty) continue;

        chapters.add(Chapter(
          title: _extractTitleFromHtml(content),
          contentHtml: content,
          href: href,
        ));
      }
    } catch (e) {
      developer.log('Failed to build chapters from spine: $e');
    }
    return chapters;
  }

  /// Look up HTML content by href from the content map
  String _lookupHtmlContent(String href, Map<String, String> htmlContentMap) {
    String? content = htmlContentMap[href];
    if (content != null && content.isNotEmpty) return content;

    String normalizedHref = href;
    while (normalizedHref.startsWith('./') || normalizedHref.startsWith('../')) {
      if (normalizedHref.startsWith('./')) {
        normalizedHref = normalizedHref.substring(2);
      } else {
        normalizedHref = normalizedHref.substring(3);
      }
    }

    content = htmlContentMap[normalizedHref];
    if (content != null && content.isNotEmpty) return content;

    final hrefFileName = href.split('/').last.toLowerCase();
    for (final key in htmlContentMap.keys) {
      final keyFileName = key.split('/').last.toLowerCase();
      if (keyFileName == hrefFileName ||
          key.toLowerCase().endsWith('/$hrefFileName')) {
        content = htmlContentMap[key];
        if (content != null && content.isNotEmpty) return content;
      }
    }
    return '';
  }

  /// Extract a readable title from file name when EPUB metadata has no title
  String _extractTitleFromFileName(String fileName) {
    String title = fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s*[\[\(（\d+[\]\)）]\s*$'), '');
    return title.trim();
  }

  /// Parse an EPUB file from a file path and return a Book object
  Future<Book> parseEpubFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = filePath.split('\\').last.split('/').last;
    return parseEpubBytes(bytes, fileName, filePath: filePath);
  }

  /// Sanitize file name to remove problematic characters
  String _sanitizeFileName(String fileName) {
    String sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')
        .trim();
    if (!sanitized.toLowerCase().endsWith('.epub')) {
      sanitized = '$sanitized.epub';
    }
    return sanitized;
  }

  /// Import an EPUB file and add to library
  Future<Book> importBook(String sourcePath, {Uint8List? fileBytes, String? fileName}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final rawFileName = fileName ?? sourcePath.split('\\').last.split('/').last;
    final actualFileName = _sanitizeFileName(rawFileName);
    final destPath = '${booksDir.path}/$actualFileName';

    Book book;
    if (fileBytes != null) {
      await File(destPath).writeAsBytes(fileBytes);
      book = await parseEpubBytes(fileBytes, actualFileName, filePath: destPath);
    } else {
      if (sourcePath.startsWith('content://')) {
        throw Exception('无法读取文件：content:// URI 需要提供文件字节数据。请确保 file_picker 的 withData 参数为 true。');
      }
      await File(sourcePath).copy(destPath);
      book = await parseEpubFile(destPath);
    }

    // 去重：同 ID 的书籍替换而非新增
    final existingIndex = _books.indexWhere((b) => b.id == book.id);
    if (existingIndex != -1) {
      // 保留旧书的阅读进度
      final oldBook = _books[existingIndex];
      book.currentChapterIndex = oldBook.currentChapterIndex;
      book.progress = oldBook.progress;
      book.isPageMode = oldBook.isPageMode;
      book.currentPage = oldBook.currentPage;
      book.scrollOffset = oldBook.scrollOffset;
      book.isDarkMode = oldBook.isDarkMode;
      _books[existingIndex] = book;
    } else {
      _books.add(book);
    }
    await _saveLibrary();

    return book;
  }

  /// Load all books from library
  Future<List<Book>> loadLibrary() async {
    final appDir = await getApplicationDocumentsDirectory();
    final libraryFile = File('${appDir.path}/library.json');

    if (await libraryFile.exists()) {
      try {
        final jsonStr = await libraryFile.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _books = jsonList.map((j) => Book.fromJson(j)).toList();
      } catch (e) {
        developer.log('Failed to load library: $e');
        _books = [];
      }
    }

    return _books;
  }

  /// Save library to local storage
  Future<void> _saveLibrary() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final libraryFile = File('${appDir.path}/library.json');
      final jsonStr = json.encode(_books.map((b) => b.toJson()).toList());
      await libraryFile.writeAsString(jsonStr);
    } catch (e) {
      developer.log('Failed to save library: $e');
    }
  }

  /// Update book progress and reading state
  Future<void> updateProgress(String bookId, int chapterIndex, double progress,
      {bool? isPageMode, int? currentPage, double? scrollOffset, bool? isDarkMode}) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      _books[index].currentChapterIndex = chapterIndex;
      _books[index].progress = progress;
      if (isPageMode != null) _books[index].isPageMode = isPageMode;
      if (currentPage != null) _books[index].currentPage = currentPage;
      if (scrollOffset != null) _books[index].scrollOffset = scrollOffset;
      if (isDarkMode != null) _books[index].isDarkMode = isDarkMode;
      await _saveLibrary();
    }
  }

  /// Remove a book from library
  Future<void> removeBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
    await _saveLibrary();
    await deleteProgressSnapshot(bookId);
    // 同时删除该书签文件和封面缓存
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookmarkFile = File('${appDir.path}/bookmarks_$bookId.json');
      if (await bookmarkFile.exists()) await bookmarkFile.delete();
      final coverFile = File('${appDir.path}/covers/$bookId.jpg');
      if (await coverFile.exists()) await coverFile.delete();
    } catch (_) {}
  }

  // ─── 书签管理 ───

  /// 获取某本书的所有书签
  Future<List<Bookmark>> getBookmarks(String bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/bookmarks_$bookId.json');
      if (!await file.exists()) return [];
      final jsonStr = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((j) => Bookmark.fromJson(j)).toList();
    } catch (e) {
      developer.log('Failed to load bookmarks: $e');
      return [];
    }
  }

  /// 保存书签列表
  Future<void> _saveBookmarks(String bookId, List<Bookmark> bookmarks) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/bookmarks_$bookId.json');
      final jsonStr = json.encode(bookmarks.map((b) => b.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (e) {
      developer.log('Failed to save bookmarks: $e');
    }
  }

  /// 添加书签
  Future<void> addBookmark(String bookId, Bookmark bookmark) async {
    final bookmarks = await getBookmarks(bookId);
    bookmarks.add(bookmark);
    await _saveBookmarks(bookId, bookmarks);
  }

  /// 删除书签
  Future<void> removeBookmark(String bookId, String bookmarkId) async {
    final bookmarks = await getBookmarks(bookId);
    bookmarks.removeWhere((b) => b.id == bookmarkId);
    await _saveBookmarks(bookId, bookmarks);
  }

  // ─── 进度快照（独立文件，避免 library.json 序列化链路中的竞态） ───

  /// 保存阅读进度快照（退出时调用）
  Future<void> saveProgressSnapshot(String bookId, int chapterIndex, int page) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/snapshot_$bookId.json');
      final jsonStr = json.encode({
        'chapterIndex': chapterIndex,
        'page': page,
      });
      await file.writeAsString(jsonStr);
    } catch (e) {
      developer.log('Failed to save progress snapshot: $e');
    }
  }

  /// 读取阅读进度快照，无快照时返回 null
  Future<({int chapterIndex, int page})?> loadProgressSnapshot(String bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/snapshot_$bookId.json');
      if (!await file.exists()) return null;
      final jsonStr = await file.readAsString();
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return (
        chapterIndex: map['chapterIndex'] as int? ?? 0,
        page: map['page'] as int? ?? 0,
      );
    } catch (e) {
      developer.log('Failed to load progress snapshot: $e');
      return null;
    }
  }

  /// 删除进度快照（删除书籍时调用）
  Future<void> deleteProgressSnapshot(String bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/snapshot_$bookId.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  String _extractTitleFromHtml(String html) {
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    if (titleMatch != null) {
      return decodeHtmlEntities(titleMatch.group(1)?.trim() ?? 'Untitled');
    }
    final h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true).firstMatch(html);
    if (h1Match != null) {
      return stripHtml(h1Match.group(1)?.trim() ?? 'Untitled');
    }
    return 'Untitled';
  }
}
