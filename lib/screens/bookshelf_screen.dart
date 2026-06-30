import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';
import 'reader_screen.dart';

/// Riverpod provider for the library. Defined here because library_provider.dart
/// exports LibraryNotifier and LibraryState but not the provider itself.
final libraryProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

/// A set of pleasant background colours for placeholder covers.
const _placeholderColors = [
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFF42A5F5), // blue
  Color(0xFFFF7043), // deep orange
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
  Color(0xFFFFA726), // orange
  Color(0xFF8D6E63), // brown
  Color(0xFF78909C), // blue grey
];

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JustRead'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _importBook(context, notifier),
            tooltip: '导入 EPUB 文件',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.books.isEmpty
              ? _buildEmptyState(context, notifier)
              : _buildBookshelf(context, ref, state, notifier),
    );
  }

  // ---------------------------------------------------------------------------
  // Import logic
  // ---------------------------------------------------------------------------

  Future<void> _importBook(
    BuildContext context,
    LibraryNotifier notifier,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        withData: true, // 获取文件字节数据，兼容 Android content:// URI
      );

      if (result == null) return;

      final file = result.files.single;

      // 检查文件字节数据是否为空
      if (file.bytes == null || file.bytes!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件读取失败：无法获取文件数据，请尝试其他文件'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (file.path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件选择失败：无法获取文件路径，请重试'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await notifier.importBook(
        filePath: file.path!,
        fileBytes: file.bytes,
        fileName: file.name,
      );
    } catch (e) {
      if (!context.mounted) return;

      String errorMsg = '导入失败';
      final errorStr = e.toString();
      if (errorStr.contains('FormatException') || errorStr.contains('Archive')) {
        errorMsg = '文件格式错误：无法解析此 EPUB 文件，文件可能已损坏';
      } else if (errorStr.contains('FileSystemException')) {
        errorMsg = '文件读取失败：无法访问此文件，请检查文件权限';
      } else if (errorStr.contains('content://')) {
        errorMsg = '文件读取失败：Android 文件 URI 访问异常，请重试';
      } else {
        errorMsg = '导入失败: $errorStr';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openBook(BuildContext context, Book book, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: book),
      ),
    ).then((_) {
      // Refresh books after returning from reader (progress may have changed)
      ref.read(libraryProvider.notifier).refreshBooks();
    });
  }

  // ---------------------------------------------------------------------------
  // Long-press bottom sheet
  // ---------------------------------------------------------------------------

  void _showBookOptions(BuildContext context, Book book, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(),
              // 查看详情
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBookDetails(context, book);
                },
              ),
              // 删除书籍
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除书籍', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmDialog(context, book, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Book details dialog
  // ---------------------------------------------------------------------------

  void _showBookDetails(BuildContext context, Book book) {
    final chapterCount = book.chapters.length;
    final currentChapterIndex = book.currentChapterIndex;
    final currentChapterTitle = (chapterCount > 0 &&
            currentChapterIndex >= 0 &&
            currentChapterIndex < chapterCount)
        ? book.chapters[currentChapterIndex].title
        : '—';
    final progressPercent = (book.progress * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('书籍详情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('书名', book.title),
              _detailRow('作者', book.author.isNotEmpty ? book.author : '未知作者'),
              _detailRow('章节数', '$chapterCount 章'),
              _detailRow('当前章节', currentChapterTitle),
              _detailRow('阅读进度', '$progressPercent%'),
              _detailRow('阅读模式', book.isPageMode ? '翻页模式' : '滚动模式'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$label：',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation dialog
  // ---------------------------------------------------------------------------

  void _showDeleteConfirmDialog(
    BuildContext context,
    Book book,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除《${book.title}》吗？\n此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(libraryProvider.notifier).removeBook(book.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context, LibraryNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 导入 EPUB 文件',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _importBook(context, notifier),
            icon: const Icon(Icons.add),
            label: const Text('导入书籍'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookshelf grid
  // ---------------------------------------------------------------------------

  Widget _buildBookshelf(
    BuildContext context,
    WidgetRef ref,
    LibraryState state,
    LibraryNotifier notifier,
  ) {
    return RefreshIndicator(
      onRefresh: () => notifier.refreshBooks(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.books.length,
        itemBuilder: (context, index) {
          return _buildBookCard(context, state.books[index], ref);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Book card
  // ---------------------------------------------------------------------------

  Widget _buildBookCard(BuildContext context, Book book, WidgetRef ref) {
    final progressPercent = (book.progress * 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: () => _openBook(context, book, ref),
      onLongPress: () => _showBookOptions(context, book, ref),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: book.coverData != null
                    ? Image.memory(
                        book.coverData!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) =>
                            _buildPlaceholderCover(book.title),
                      )
                    : _buildPlaceholderCover(book.title),
              ),
            ),
            // Book info
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Progress bar (always visible)
                  LinearProgressIndicator(
                    value: book.progress,
                    backgroundColor: Colors.grey[200],
                    minHeight: 3,
                  ),
                  const SizedBox(height: 2),
                  // Progress percentage label
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Placeholder cover (first character of title on coloured background)
  // ---------------------------------------------------------------------------

  Widget _buildPlaceholderCover(String title) {
    final char = _firstDisplayChar(title);
    final colorIndex = title.isNotEmpty ? title.codeUnits.fold<int>(0, (a, b) => a + b) % _placeholderColors.length : 0;
    final bgColor = _placeholderColors[colorIndex];

    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Returns the first displayable character of [title].
  /// For CJK scripts the first character is returned as-is.
  /// For Latin scripts the first letter is uppercased.
  /// Falls back to '?' for empty strings.
  String _firstDisplayChar(String title) {
    if (title.isEmpty) return '?';

    final first = title[0];

    // Check if it's a CJK character (CJK Unified Ideographs, CJK Extension A,
    // CJK Compatibility Ideographs, etc.)
    final code = first.codeUnitAt(0);
    final isCJK = (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified
        (code >= 0x3400 && code <= 0x4DBF) || // CJK Extension A
        (code >= 0xF900 && code <= 0xFAFF) || // CJK Compatibility
        (code >= 0x3000 && code <= 0x303F) || // CJK Symbols
        (code >= 0xFF00 && code <= 0xFFEF) || // Halfwidth/Fullwidth
        (code >= 0x2E80 && code <= 0x2FDF); // CJK Radicals Supplement

    if (isCJK) return first;

    // For Latin and other scripts, return the first letter uppercased
    final letter = RegExp(r'[a-zA-Z]').firstMatch(first);
    if (letter != null) return letter.group(0)!.toUpperCase();

    // Fallback: return first character as-is if it's printable
    return first;
  }
}
