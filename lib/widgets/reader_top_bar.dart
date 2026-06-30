import 'package:flutter/material.dart';
import '../providers/reader_provider.dart';

/// 阅读器顶部栏：返回按钮 + 章节标题（浮层，不挤压内容）
class ReaderTopBar extends StatelessWidget {
  final ReaderState state;
  final VoidCallback onBack;

  const ReaderTopBar({
    super.key,
    required this.state,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = state.isDarkMode ? Colors.white : Colors.black87;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 0,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: (state.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white)
            .withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: 20, color: textColor),
            onPressed: onBack,
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Text(
              state.book.chapters.isNotEmpty
                  ? state.book.chapters[state.currentChapterIndex].title
                  : state.book.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
