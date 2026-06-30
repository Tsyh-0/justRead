import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:justread/main.dart';

void main() {
  testWidgets('app starts and shows bookshelf title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JustReadApp()));
    await tester.pump();

    // 标题始终可见
    expect(find.text('JustRead'), findsOneWidget);
    // 骨架完好
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
