import 'package:flutter/material.dart';
import '../providers/reader_provider.dart';

/// 目录 Bottom Sheet
class TocSheet extends StatelessWidget {
  final ReaderState state;
  final void Function(int index) onJump;
  final double screenHeight;

  const TocSheet({
    super.key,
    required this.state,
    required this.onJump,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '目录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: state.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: state.book.chapters.length,
              itemBuilder: (ctx, index) {
                final chapter = state.book.chapters[index];
                final isCurrent = index == state.currentChapterIndex;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.bookmark : Icons.article_outlined,
                    size: 18,
                    color: isCurrent
                        ? Colors.blue
                        : (state.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  title: Text(
                    chapter.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? Colors.blue
                          : (state.isDarkMode ? Colors.white : Colors.black87),
                    ),
                  ),
                  trailing: isCurrent
                      ? const Text('当前', style: TextStyle(fontSize: 12, color: Colors.blue))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onJump(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
