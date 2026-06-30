import 'dart:typed_data';
import 'dart:convert';

class Book {
  final String id;
  final String title;
  final String author;
  final String? coverPath;
  final Uint8List? coverData;
  final String filePath;
  final List<Chapter> chapters;
  int currentChapterIndex;
  double progress;
  bool isPageMode;
  int currentPage;
  /// 滚动模式下的章节内滚动偏移（像素），恢复精确阅读位置
  double scrollOffset;
  /// 阅读器暗色模式偏好
  bool isDarkMode;

  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.coverPath,
    this.coverData,
    required this.filePath,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.progress = 0.0,
    this.isPageMode = true, // EPUB 默认翻页模式
    this.currentPage = 0,
    this.scrollOffset = 0.0,
    this.isDarkMode = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverPath': coverPath,
        'coverData': coverData != null ? base64Encode(coverData!) : null,
        'filePath': filePath,
        'currentChapterIndex': currentChapterIndex,
        'progress': progress,
        'isPageMode': isPageMode,
        'currentPage': currentPage,
        'scrollOffset': scrollOffset,
        'isDarkMode': isDarkMode,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    final coverDataStr = json['coverData'] as String?;
    final chaptersList = json['chapters'] as List<dynamic>?;

    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      coverData: coverDataStr != null ? Uint8List.fromList(base64Decode(coverDataStr)) : null,
      filePath: json['filePath'] as String,
      currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      isPageMode: json['isPageMode'] as bool? ?? true,
      currentPage: json['currentPage'] as int? ?? 0,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      chapters: chaptersList != null
          ? chaptersList.map((c) => Chapter.fromJson(c as Map<String, dynamic>)).toList()
          : [],
    );
  }
}

class Bookmark {
  final String id;
  final int chapterIndex;
  final String chapterTitle;
  final double progressInChapter; // 0.0 ~ 1.0，章节内位置比例
  final String textSnippet; // 书签附近文字片段
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.progressInChapter,
    required this.textSnippet,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'progressInChapter': progressInChapter,
        'textSnippet': textSnippet,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        chapterIndex: json['chapterIndex'] as int,
        chapterTitle: json['chapterTitle'] as String? ?? '',
        progressInChapter: (json['progressInChapter'] as num).toDouble(),
        textSnippet: json['textSnippet'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Chapter {
  final String title;
  final String contentHtml;
  final String? href;

  Chapter({
    required this.title,
    required this.contentHtml,
    this.href,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'contentHtml': contentHtml,
        'href': href,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        title: json['title'] as String? ?? 'Untitled',
        contentHtml: json['contentHtml'] as String? ?? '',
        href: json['href'] as String?,
      );
}