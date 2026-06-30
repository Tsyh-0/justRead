import 'package:flutter/material.dart';

/// 字号调节对话框
class FontSizeDialog extends StatelessWidget {
  final double currentSize;
  final ValueChanged<double> onChanged;

  const FontSizeDialog({
    super.key,
    required this.currentSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    double tempSize = currentSize;
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('字体大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前: ${tempSize.toInt()}px'),
              Slider(
                value: tempSize,
                min: 12,
                max: 36,
                divisions: 24, // 36-12=24，所以 divisions=24 是安全的
                label: '${tempSize.toInt()}px',
                onChanged: (value) {
                  setDialogState(() {
                    tempSize = value;
                    onChanged(value);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
