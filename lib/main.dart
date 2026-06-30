import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/bookshelf_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: JustReadApp(),
    ),
  );
}

class JustReadApp extends StatelessWidget {
  const JustReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JustRead',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const BookshelfScreen(),
    );
  }
}
