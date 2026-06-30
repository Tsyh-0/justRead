import 'package:flutter/material.dart';
import '../providers/reader_provider.dart';

/// 阅读器底部控制栏：进度条 + 字体调节 + 目录 + 模式切换 + 夜间模式
class ReaderBottomBar extends StatelessWidget {
  final ReaderState state;
  final ReaderNotifier notifier;
  final VoidCallback onShowToc;
  final VoidCallback onShowFontDialog;
  final VoidCallback? onFontSizeChanged;
  final VoidCallback? onAddBookmark;
  final VoidCallback? onShowBookmarks;
  final VoidCallback? onToggleMode;

  const ReaderBottomBar({
    super.key,
    required this.state,
    required this.notifier,
    required this.onShowToc,
    required this.onShowFontDialog,
    this.onFontSizeChanged,
    this.onAddBookmark,
    this.onShowBookmarks,
    this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        left: 12,
        right: 12,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: (state.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white)
            .withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          if (state.book.chapters.isNotEmpty) _buildProgressBar(),
          const SizedBox(height: 6),
          // 控制按钮行
          _buildControlsRow(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            notifier.progressIndicator,
            style: TextStyle(
              fontSize: 12,
              color: state.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor:
                    state.isDarkMode ? Colors.blue[300] : Colors.blue[600],
                inactiveTrackColor:
                    state.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                thumbColor:
                    state.isDarkMode ? Colors.blue[300] : Colors.blue[600],
                overlayColor: (state.isDarkMode ? Colors.blue : Colors.blue)
                    .withValues(alpha: 0.12),
              ),
              child: Slider(
                value: state.isPageMode
                    ? state.currentPage.toDouble()
                    : state.currentChapterIndex.toDouble(),
                min: 0,
                max: state.isPageMode
                    ? (state.pages.length - 1).toDouble().clamp(0, double.infinity)
                    : (state.book.chapters.length - 1)
                        .toDouble()
                        .clamp(0, double.infinity),
                divisions: state.isPageMode
                    ? (state.pages.length > 1 ? state.pages.length - 1 : null)
                    : (state.book.chapters.length > 1
                        ? state.book.chapters.length - 1
                        : null),
                onChanged: (value) {
                  if (state.isPageMode) {
                    notifier.setCurrentPage(value.toInt());
                  } else {
                    notifier.jumpToChapter(value.toInt());
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 字体控制
          _buildFontControls(),
          // 书签 + 目录
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onAddBookmark != null)
                _buildSmallButton(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: '添加书签',
                  onTap: onAddBookmark!,
                ),
              if (onShowBookmarks != null)
                _buildSmallButton(
                  icon: Icons.bookmarks_outlined,
                  tooltip: '书签列表',
                  onTap: onShowBookmarks!,
                ),
              _buildSmallButton(
                icon: Icons.list,
                label: '目录',
                onTap: onShowToc,
              ),
            ],
          ),
          // 模式 + 夜间模式
          _buildModeControls(),
        ],
      ),
    );
  }

  Widget _buildFontControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallButton(
          label: 'A-',
          onTap: () {
            if (state.fontSize > 14) {
              notifier.setFontSize(state.fontSize - 2);
              onFontSizeChanged?.call();
            }
          },
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onShowFontDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${state.fontSize.toInt()}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: state.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        _buildSmallButton(
          label: 'A+',
          onTap: () {
            if (state.fontSize < 32) {
              notifier.setFontSize(state.fontSize + 2);
              onFontSizeChanged?.call();
            }
          },
        ),
      ],
    );
  }

  Widget _buildModeControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallButton(
          icon: state.isPageMode ? Icons.unfold_more : Icons.swipe_vertical,
          tooltip: state.isPageMode ? '滚动模式' : '翻页模式',
          onTap: onToggleMode ?? () => notifier.togglePageMode(),
        ),
        const SizedBox(width: 2),
        _buildSmallButton(
          icon: state.isDarkMode
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          tooltip: state.isDarkMode ? '日间模式' : '夜间模式',
          onTap: () => notifier.toggleDarkMode(),
        ),
      ],
    );
  }

  Widget _buildSmallButton({
    IconData? icon,
    String? label,
    String? tooltip,
    required VoidCallback onTap,
  }) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor:
            (state.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
        highlightColor:
            (state.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: icon != null
              ? Icon(icon, size: 20, color: state.isDarkMode ? Colors.white70 : Colors.black54)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: state.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: child);
    return child;
  }
}
