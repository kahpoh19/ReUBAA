/// 只有 HTML 正文的信转成纯文本显示，不引入网页渲染。
///
/// 去掉样式和脚本，块级标签换行，列表项加圆点，再解开常见的字符实体。
String mailHtmlToText(String html) {
  var text = html
      .replaceAll(
        RegExp(
          r'<(head|style|script|title)[^>]*>.*?</\1>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(
        RegExp(
          r'</(p|div|tr|h[1-6]|blockquote|table|ul|ol)>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  text = _unescape(text);
  final lines = text.split('\n').map((line) => line.trimRight()).toList();
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

const _entities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'middot': '·',
  'copy': '©',
};

String _unescape(String text) => text.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
  (match) {
    final name = match[1]!;
    if (name.startsWith('#x') || name.startsWith('#X')) {
      final code = int.tryParse(name.substring(2), radix: 16);
      return code == null ? match[0]! : String.fromCharCode(code);
    }
    if (name.startsWith('#')) {
      final code = int.tryParse(name.substring(1));
      return code == null ? match[0]! : String.fromCharCode(code);
    }
    return _entities[name.toLowerCase()] ?? match[0]!;
  },
);
