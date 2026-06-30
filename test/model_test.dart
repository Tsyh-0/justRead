import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:justread/models/book.dart';

void main() {
  group('Book serialization', () {
    test('toJson and fromJson round-trip', () {
      final book = Book(
        id: 'test_id_001',
        title: '测试书籍',
        author: '测试作者',
        coverData: Uint8List.fromList([1, 2, 3, 4]),
        filePath: '/test/path.epub',
        currentChapterIndex: 2,
        progress: 0.5,
        isPageMode: true,
        currentPage: 10,
        scrollOffset: 350.0,
        isDarkMode: true,
        chapters: [
          Chapter(title: 'Chapter 1', contentHtml: '<p>Hello</p>'),
          Chapter(title: 'Chapter 2', contentHtml: '<p>World</p>'),
        ],
      );

      final json = book.toJson();
      final restored = Book.fromJson(json);

      expect(restored.id, 'test_id_001');
      expect(restored.title, '测试书籍');
      expect(restored.author, '测试作者');
      expect(restored.coverData, isNotNull);
      expect(restored.coverData!.length, 4);
      expect(restored.filePath, '/test/path.epub');
      expect(restored.currentChapterIndex, 2);
      expect(restored.progress, 0.5);
      expect(restored.isPageMode, true);
      expect(restored.currentPage, 10);
      expect(restored.scrollOffset, 350.0);
      expect(restored.isDarkMode, true);
      expect(restored.chapters.length, 2);
      expect(restored.chapters[0].title, 'Chapter 1');
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{
        'id': 'minimal',
        'title': 'Minimal Book',
        'filePath': '/a/b.epub',
      };

      final book = Book.fromJson(json);

      expect(book.id, 'minimal');
      expect(book.author, '');
      expect(book.coverData, isNull);
      expect(book.progress, 0.0);
      expect(book.isPageMode, true);
      expect(book.currentPage, 0);
      expect(book.scrollOffset, 0.0);
      expect(book.isDarkMode, false);
      expect(book.chapters, isEmpty);
    });

    test('progress is parsed as double from int', () {
      final json = <String, dynamic>{
        'id': 'p',
        'title': 'P',
        'filePath': '',
        'progress': 1,
      };

      final book = Book.fromJson(json);
      expect(book.progress, 1.0);
      expect(book.progress, isA<double>());
    });
  });

  group('Bookmark serialization', () {
    test('toJson and fromJson round-trip', () {
      final createdAt = DateTime(2026, 6, 26, 15, 30);
      final bookmark = Bookmark(
        id: 'bm_001',
        chapterIndex: 3,
        chapterTitle: '第三章 测试',
        progressInChapter: 0.42,
        textSnippet: '这是一段测试文本片段用于验证...',
        createdAt: createdAt,
      );

      final json = bookmark.toJson();
      final restored = Bookmark.fromJson(json);

      expect(restored.id, 'bm_001');
      expect(restored.chapterIndex, 3);
      expect(restored.chapterTitle, '第三章 测试');
      expect(restored.progressInChapter, 0.42);
      expect(restored.textSnippet, '这是一段测试文本片段用于验证...');
      expect(restored.createdAt, createdAt);
    });
  });

  group('Chapter serialization', () {
    test('toJson and fromJson', () {
      final chapter = Chapter(
        title: 'Title',
        contentHtml: '<p>Content</p>',
        href: 'chapter1.xhtml',
      );

      final json = chapter.toJson();
      final restored = Chapter.fromJson(json);

      expect(restored.title, 'Title');
      expect(restored.contentHtml, '<p>Content</p>');
      expect(restored.href, 'chapter1.xhtml');
    });

    test('fromJson handles missing fields', () {
      final restored = Chapter.fromJson(<String, dynamic>{});
      expect(restored.title, 'Untitled');
      expect(restored.contentHtml, '');
      expect(restored.href, isNull);
    });
  });
}
