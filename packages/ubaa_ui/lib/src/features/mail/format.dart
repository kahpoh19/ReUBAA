import 'package:ubaa_domain/ubaa_domain.dart';
import '../../shared/when.dart' show uiCampusNow, uiClock, uiDay;

const mailTitle = '北航邮箱';

/// 列表里的时间：当天只显示钟点，其余显示日期。
String mailListTime(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final at = homeCampusTime(date);
  final current = now ?? uiCampusNow();
  final today =
      at.year == current.year &&
      at.month == current.month &&
      at.day == current.day;
  return today ? uiClock(at) : uiDay(at, now: current);
}

String mailFullTime(DateTime? date, {DateTime? now}) {
  if (date == null) return '—';
  final at = homeCampusTime(date);
  return '${uiDay(at, now: now)} ${uiClock(at)}';
}

/// `张三 <zhangsan@buaa.edu.cn>`，没有名字时只显示地址。
String mailContactText(MailContact contact) {
  final name = contact.name?.trim();
  return name == null || name.isEmpty
      ? contact.address
      : '$name <${contact.address}>';
}

String mailSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// 收件人按逗号、分号或空白分开；只写用户名的补上学校域名。
List<String> mailAddresses(String input) => [
  for (final part in input.split(RegExp(r'[,，;；\s]+')))
    if (part.trim().isNotEmpty) buaaMailAddress(part),
];

final _replyPrefix = RegExp(r'^\s*(re|回复)\s*[:：]', caseSensitive: false);

String mailReplySubject(String subject) =>
    _replyPrefix.hasMatch(subject) ? subject : 'Re: $subject';

/// 回复时在正文下面引用原信，每行加“> ”。
String mailQuote(MailMessage message, {DateTime? now}) {
  final from = message.summary.from?.label ?? '对方';
  final time = mailFullTime(message.summary.date, now: now);
  final quoted = message.text.split('\n').map((line) => '> $line').join('\n');
  return '\n\n在 $time，$from 写道：\n$quoted';
}
