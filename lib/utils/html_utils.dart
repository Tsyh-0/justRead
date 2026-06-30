/// 共享 HTML 处理工具。
///
/// 解决 `reader_screen.dart` 和 `epub_service.dart` 中 `_stripHtml` /
/// `_decodeHtmlEntities` 三处重复的问题。
library;

/// 将 HTML 转换为纯文本。
///
/// 依次执行：去除 script/style → 块级标签/br 替换为换行 →
/// 去除所有标签 → 解码 HTML 实体 → 归一化换行符（CRLF/CR→LF）→
/// 合并连续换行 → trim。
String stripHtml(String html) {
  if (html.isEmpty) return '';

  var text = html.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
  text = text.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');
  text = text.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(
      RegExp(r'<(p|div|h[1-6]|li|blockquote)[^>]*>', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');

  text = decodeHtmlEntities(text);

  // 归一化换行符：某些 EPUB 使用 CRLF (\r\n) 或 CR (\r)，如不处理
  // 后续 \n{3,} 正则会因数 \r 隔断而失效
  text = text.replaceAll('\r\n', '\n');
  text = text.replaceAll('\r', '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}

/// 解码常见 HTML 命名实体和数字实体（十进制 &#XXXX; 与十六进制 &#xXXXX;）。
String decodeHtmlEntities(String text) {
  const namedEntities = <String, String>{
    '&lt;': '<', '&gt;': '>', '&quot;': '"', '&apos;': "'",
    '&#39;': "'", '&#x27;': "'", '&amp;': '&', '&nbsp;': '\u00a0',
    '&mdash;': '\u2014', '&ndash;': '\u2013', '&hellip;': '\u2026',
    '&lsquo;': '\u2018', '&rsquo;': '\u2019', '&ldquo;': '\u201c',
    '&rdquo;': '\u201d', '&bull;': '\u2022', '&middot;': '\u00b7',
    '&copy;': '\u00a9', '&reg;': '\u00ae', '&trade;': '\u2122',
    '&deg;': '\u00b0', '&plusmn;': '\u00b1', '&times;': '\u00d7',
    '&divide;': '\u00f7', '&sect;': '\u00a7', '&para;': '\u00b6',
  };

  String result = text;

  // Named entities (must precede numeric to avoid double-decoding)
  for (final entry in namedEntities.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }

  // Decimal numeric entities: &#XXXX;
  result = result.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );

  // Hex numeric entities: &#xXXXX;
  result = result.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );

  return result;
}
