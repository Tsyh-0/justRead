import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:justread/models/book.dart';
import 'package:justread/screens/reader_screen.dart';

Book _makeTestBook({String contentHtml = '<p>Hello <b>world</b> &amp; goodbye.</p>'}) {
  return Book(
    id: 'test-book',
    title: 'Test Book',
    filePath: '/tmp/test.epub',
    chapters: [
      Chapter(title: 'Chapter One', contentHtml: contentHtml),
    ],
  );
}

void main() {
  testWidgets('renders chapter text without HTML tags', (tester) async {
    final book = _makeTestBook();

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: ReaderScreen(book: book))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('<p>'), findsNothing);
    expect(find.textContaining('<b>'), findsNothing);
    expect(find.textContaining('Hello'), findsWidgets);
    expect(find.textContaining('world'), findsWidgets);
    expect(find.textContaining('goodbye'), findsWidgets);
    expect(find.textContaining('&amp;'), findsNothing);
  });

  testWidgets('shows fallback when no chapters', (tester) async {
    final book = Book(id: 'empty', title: 'Empty', filePath: '/tmp/e.epub', chapters: []);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: ReaderScreen(book: book))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('无法解析章节内容'), findsOneWidget);
  });

  testWidgets('renders in dark mode without crash', (tester) async {
    final book = _makeTestBook();
    book.isDarkMode = true;

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: ReaderScreen(book: book))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ReaderScreen), findsOneWidget);
  });
}
