import 'dart:io';
import 'package:epubx/epubx.dart';

void main() async {
  const epubPath = r"C:\Users\35368\Downloads\vanSP\龙族全套 共6册（龙族1火之晨曦 龙族2悼亡者之瞳 龙族3黑月之潮上中下册 龙族4奥丁之渊） (.epub";

  final bytes = await File(epubPath).readAsBytes();
  final epubBook = await EpubReader.readBook(bytes);

  final htmlMap = <String, String>{};
  if (epubBook.Content?.Html != null) {
    for (final e in epubBook.Content!.Html!.entries) {
      final c = e.value.Content ?? '';
      if (c.isNotEmpty) htmlMap[e.key] = c;
    }
  }

  // 递归收集章节
  final chapters = <({String title, String html, String href})>[];
  void collect(EpubChapter ch) {
    String content = ch.HtmlContent ?? '';
    final href = ch.ContentFileName;
    if (content.isEmpty && href != null && href.isNotEmpty) {
      content = htmlMap[href] ?? '';
      if (content.isEmpty) {
        for (final key in htmlMap.keys) {
          if (key.endsWith(href.split('/').last)) {
            content = htmlMap[key] ?? '';
            break;
          }
        }
      }
    }
    if (content.isNotEmpty) {
      chapters.add((title: ch.Title ?? '?', html: content, href: href ?? '?'));
    }
    if (ch.SubChapters != null) {
      for (final sub in ch.SubChapters!) {
        collect(sub);
      }
    }
  }
  if (epubBook.Chapters != null) {
    for (final ch in epubBook.Chapters!) {
      collect(ch);
    }
  }

  // 找到标题包含"尾声"或"序"的章节
  for (final ch in chapters) {
    if (ch.title.contains('尾声') || ch.title.contains('序') || ch.title.contains('开篇')) {
      print('=== ${ch.title} (href: ${ch.href}, html_len: ${ch.html.length}) ===');

      // 统计 HTML 源码中的连续空行
      final rawBlankLines = RegExp(r'\n\s*\n\s*\n').allMatches(ch.html).length;

      // 打印原始 HTML 的前 2000 字符
      print('--- 原始 HTML (前2000字符) ---');
      print(ch.html.substring(0, ch.html.length < 2000 ? ch.html.length : 2000));

      // 打印 strip 后的文本（前1000字符，显示换行）
      final stripped = ch.html
          .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
          .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
          .replaceAll(RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<(p|div|h[1-6]|li|blockquote)[^>]*>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      print('\n--- strip后 (前1000字符，\\n 显示为 ↵) ---');
      final display = stripped
          .substring(0, stripped.length < 1000 ? stripped.length : 1000)
          .replaceAll('\n', '↵\n');
      print(display);

      print('\n--- 统计 ---');
      print('HTML源码连续空行(3+ \n): $rawBlankLines');
      print('strip后连续换行(3+): ${RegExp(r'\n{3,}').allMatches(stripped).length}');
      print('strip后双换行: ${RegExp(r'\n\n').allMatches(stripped).length}');
      print('\n');
    }
  }
}
