import 'dart:io';
import 'package:epubx/epubx.dart';

void printChapter(EpubChapter ch, int depth) {
  final indent = '  ' * depth;
  final htmlLen = ch.HtmlContent?.length ?? 0;
  print('${indent}[${ch.Title}] ContentFileName="${ch.ContentFileName}" HtmlContent.length=$htmlLen SubChapters=${ch.SubChapters?.length ?? 0}');
  if (ch.SubChapters != null) {
    for (final sub in ch.SubChapters!) {
      printChapter(sub, depth + 1);
    }
  }
}

void main() async {
  const epubPath = r"C:\Users\35368\Downloads\vanSP\龙族全套 共6册（龙族1火之晨曦 龙族2悼亡者之瞳 龙族3黑月之潮上中下册 龙族4奥丁之渊） (.epub";

  print('=== Reading EPUB file ===');
  final bytes = await File(epubPath).readAsBytes();
  print('File size: ${bytes.length} bytes');

  print('\n=== Parsing with epubx ===');
  final epubBook = await EpubReader.readBook(bytes);

  print('Title: ${epubBook.Title}');
  print('Author: ${epubBook.Author}');

  // Chapters with SubChapters
  print('\n--- Chapters (with SubChapters) ---');
  final chapters = epubBook.Chapters;
  print('Chapters count: ${chapters?.length ?? 0}');
  if (chapters != null) {
    for (int i = 0; i < chapters.length; i++) {
      printChapter(chapters[i], 0);
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

  // Now let's see what the first chapter's content would look like
  // if we merge all HTML files from text00001.html to text00017.html
  print('\n--- Manual content merge for Chapter 0 (龙族Ⅰ·火之晨曦) ---');
  print('ContentFileName = text00001.html');
  print('Content from htmlContentMap[text00001.html] length = ${htmlContentMap["text00001.html"]?.length ?? 0}');
  
  // Find all files between text00001.html and text00017.html (inclusive)
  final List<String> sortedKeys = htmlContentMap.keys.toList()..sort();
  print('\nAll sorted HTML keys:');
  for (final key in sortedKeys) {
    print('  $key (${htmlContentMap[key]?.length ?? 0} bytes)');
  }
}
