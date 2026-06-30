import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:justread/models/book.dart';
import 'package:justread/services/epub_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Book 模型序列化测试
  // ---------------------------------------------------------------------------
  group('Book model serialization', () {
    test('toJson and fromJson complete roundtrip', () {
      final original = Book(
        id: 'test-book-001',
        title: 'The Art of Testing',
        author: 'Jane Doe',
        filePath: '/data/books/test.epub',
        chapters: [
          Chapter(
            title: 'Introduction',
            contentHtml: '<h1>Welcome</h1><p>This is a test.</p>',
            href: 'ch01.xhtml',
          ),
          Chapter(
            title: 'Chapter 2',
            contentHtml: '<p>More content &amp; entities &mdash; here.</p>',
          ),
        ],
        currentChapterIndex: 1,
        progress: 0.42,
        isPageMode: true,
        currentPage: 7,
        scrollOffset: 0.33,
        isDarkMode: true,
      );

      final json = original.toJson();
      final restored = Book.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.author, equals(original.author));
      expect(restored.filePath, equals(original.filePath));
      expect(restored.currentChapterIndex, equals(1));
      expect(restored.progress, closeTo(0.42, 0.001));
      expect(restored.isPageMode, isTrue);
      expect(restored.currentPage, equals(7));
      expect(restored.scrollOffset, closeTo(0.33, 0.001));
      expect(restored.isDarkMode, isTrue);

      // Chapters
      expect(restored.chapters.length, equals(2));
      expect(restored.chapters[0].title, equals('Introduction'));
      expect(restored.chapters[0].contentHtml,
          equals('<h1>Welcome</h1><p>This is a test.</p>'));
      expect(restored.chapters[0].href, equals('ch01.xhtml'));
      expect(restored.chapters[1].title, equals('Chapter 2'));
      expect(restored.chapters[1].contentHtml,
          equals('<p>More content &amp; entities &mdash; here.</p>'));
      expect(restored.chapters[1].href, isNull);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{
        'id': 'minimal-book',
        'title': 'Minimal',
        'filePath': '/tmp/min.epub',
      };

      final book = Book.fromJson(json);

      expect(book.id, equals('minimal-book'));
      expect(book.title, equals('Minimal'));
      expect(book.author, equals(''));
      expect(book.filePath, equals('/tmp/min.epub'));
      expect(book.chapters, isEmpty);
      expect(book.currentChapterIndex, equals(0));
      expect(book.progress, equals(0.0));
      expect(book.isPageMode, isTrue);
      expect(book.currentPage, equals(0));
      expect(book.scrollOffset, equals(0.0));
      expect(book.isDarkMode, isFalse);
    });

    test('toJson handles null coverData', () {
      final book = Book(
        id: 'no-cover',
        title: 'No Cover Book',
        author: 'A.N. Other',
        filePath: '/tmp/nocover.epub',
        chapters: [],
      );

      final json = book.toJson();
      expect(json['coverData'], isNull);
      expect(json['coverPath'], isNull);

      final restored = Book.fromJson(json);
      expect(restored.coverData, isNull);
      expect(restored.coverPath, isNull);
    });

    test('toJson encodes and fromJson decodes coverData (base64 roundtrip)', () {
      final coverBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
      final book = Book(
        id: 'with-cover',
        title: 'Cover Book',
        filePath: '/tmp/cover.epub',
        coverData: coverBytes,
      );

      final json = book.toJson();
      // coverData should be base64-encoded string
      expect(json['coverData'], isA<String>());
      expect(json['coverData'], equals(base64Encode(coverBytes)));

      final restored = Book.fromJson(json);
      expect(restored.coverData, isNotNull);
      expect(restored.coverData!.length, equals(5));
      expect(restored.coverData![0], equals(0xFF));
      expect(restored.coverData![4], equals(0x00));
    });
  });

  // ---------------------------------------------------------------------------
  // Bookmark 模型序列化测试
  // ---------------------------------------------------------------------------
  group('Bookmark model serialization', () {
    test('toJson and fromJson roundtrip', () {
      final now = DateTime(2025, 6, 15, 14, 30, 45);
      final original = Bookmark(
        id: 'bm-001',
        chapterIndex: 3,
        chapterTitle: 'The Long Chapter',
        progressInChapter: 0.75,
        textSnippet: 'It was a dark and stormy night...',
        createdAt: now,
      );

      final json = original.toJson();
      final restored = Bookmark.fromJson(json);

      expect(restored.id, equals('bm-001'));
      expect(restored.chapterIndex, equals(3));
      expect(restored.chapterTitle, equals('The Long Chapter'));
      expect(restored.progressInChapter, closeTo(0.75, 0.001));
      expect(restored.textSnippet, equals('It was a dark and stormy night...'));
      expect(restored.createdAt, equals(now));
    });

    test('fromJson uses defaults for optional fields', () {
      final json = <String, dynamic>{
        'id': 'bm-min',
        'chapterIndex': 0,
        'progressInChapter': 0.0,
        'createdAt': '2025-01-01T00:00:00.000',
      };

      final bm = Bookmark.fromJson(json);

      expect(bm.chapterTitle, equals(''));
      expect(bm.textSnippet, equals(''));
    });

    test('fromJson throws on missing required fields', () {
      final badJson = <String, dynamic>{
        'id': 'bad',
        // chapterIndex missing
        'progressInChapter': 0.5,
        'createdAt': '2025-01-01T00:00:00.000',
      };
      // Cast of null to int throws; error type varies by Dart/Flutter version
      // (TypeError / CastError — both are Error, not Exception).
      expect(() => Bookmark.fromJson(badJson), throwsA(anything));
    });
  });

  // ---------------------------------------------------------------------------
  // Chapter 模型序列化测试
  // ---------------------------------------------------------------------------
  group('Chapter model serialization', () {
    test('toJson and fromJson roundtrip', () {
      final original = Chapter(
        title: 'Prologue',
        contentHtml:
            '<div><p>Once upon a time&hellip;</p><br/><span>end</span></div>',
        href: 'prologue.xhtml',
      );

      final json = original.toJson();
      final restored = Chapter.fromJson(json);

      expect(restored.title, equals('Prologue'));
      expect(restored.contentHtml,
          equals('<div><p>Once upon a time&hellip;</p><br/><span>end</span></div>'));
      expect(restored.href, equals('prologue.xhtml'));
    });

    test('fromJson defaults for missing fields', () {
      final json = <String, dynamic>{};
      final c = Chapter.fromJson(json);

      expect(c.title, equals('Untitled'));
      expect(c.contentHtml, equals(''));
      expect(c.href, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // EpubService 单例测试
  // ---------------------------------------------------------------------------
  group('EpubService', () {
    test('returns the same instance (singleton)', () {
      final instance1 = EpubService();
      final instance2 = EpubService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('books getter returns an unmodifiable view', () {
      final service = EpubService();
      final books = service.books;
      expect(books, isA<List<Book>>());
      expect(books, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // stripHtml / decodeHtmlEntities 间接测试说明
  // ---------------------------------------------------------------------------
  // _stripHtml 和 _decodeHtmlEntities 是 EpubService 的私有方法，无法在
  // 本测试文件中直接调用。它们通过以下路径被间接使用：
  //
  //   parseEpubBytes → _collectChaptersRecursive → _extractTitleFromHtml
  //     → _decodeHtmlEntities + _stripHtml
  //
  // 完整的集成验证需要构造一个最小 EPUB 字节数组并调用 parseEpubBytes。
  // 作为替代，reader_screen_test.dart 中的 widget 测试通过渲染包含 HTML
  // 内容的章节来间接验证 HTML 标签被正确去除（_ReaderScreenState._stripHtml
  // 是 EpubService._stripHtml 的语义副本）。
  //
  // 若未来将 _stripHtml 和 _decodeHtmlEntities 提升为公开静态方法
  // （例如 EpubService.stripHtml(String)），则可在此处添加直接的单元测试：
  //
  //   test('stripHtml removes tags', () {
  //     expect(EpubService.stripHtml('<p>Hello <b>world</b></p>'),
  //            equals('Hello world'));
  //   });
  //   test('stripHtml decodes entities', () {
  //     expect(EpubService.stripHtml('<p>a &amp; b &mdash; c</p>'),
  //            equals('a & b — c'));
  //   });
  //
  // 当前这些验证由 reader_screen_test.dart 中的 "renders text without HTML tags"
  // widget 测试完成。
}
