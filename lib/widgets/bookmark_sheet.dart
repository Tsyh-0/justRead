import 'package:flutter/material.dart';
import '../models/book.dart';

/// 书签列表 Bottom Sheet
class BookmarkSheet extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final bool isDarkMode;
  final void Function(Bookmark bookmark) onJump;
  final void Function(String bookmarkId) onDelete;

  const BookmarkSheet({
    super.key,
    required this.bookmarks,
    required this.isDarkMode,
    required this.onJump,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '书签 (${bookmarks.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '暂无书签',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: bookmarks.length,
                itemBuilder: (ctx, index) {
                  final bm = bookmarks[index];
                  return ListTile(
                    leading: Icon(
                      Icons.bookmark,
                      size: 18,
                      color: isDarkMode ? Colors.amber[300] : Colors.amber[700],
                    ),
                    title: Text(
                      bm.chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      bm.textSnippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () => onDelete(bm.id),
                      splashRadius: 16,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onJump(bm);
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
