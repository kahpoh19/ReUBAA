import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../../common/detail_fields.dart';
import '../../common/state_panel.dart';
import '../../shared/dialogs/sheet.dart' show UiInfoRow;
import '../../shared/loading.dart' show LoadingPlaceholder;
import '../../theme.dart';
import 'format.dart';

/// 打开的一封信。正文按纯文本显示，附件只列出名字和大小。
class MailReaderPage extends StatefulWidget {
  const MailReaderPage({
    required this.service,
    required this.summary,
    required this.onReply,
    super.key,
  });
  final MailService service;
  final MailSummary summary;
  final Future<void> Function(MailMessage message) onReply;
  @override
  State<MailReaderPage> createState() => _MailReaderPageState();
}

class _MailReaderPageState extends State<MailReaderPage> {
  MailMessage? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final message = await widget.service.read(
        widget.summary.folder,
        widget.summary.uid,
      );
      if (mounted) setState(() => _message = message);
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is MailException ? error.message : '读取失败，请稍后重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Scaffold(
      appBar: AppBar(
        title: const Text('邮件'),
        centerTitle: false,
        actions: [
          if (message != null)
            IconButton(
              tooltip: '回复',
              onPressed: () => widget.onReply(message),
              icon: const Icon(Icons.reply),
            ),
        ],
      ),
      body: message != null
          ? _MailBody(message: message)
          : _error != null
          ? UiStatePanel(
              icon: Icons.cloud_off_outlined,
              title: '邮件读取失败',
              detail: _error,
              action: '重试',
              actionIcon: Icons.refresh,
              onAction: _load,
            )
          : const LoadingPlaceholder(),
    );
  }
}

class _MailBody extends StatelessWidget {
  const _MailBody({required this.message});
  final MailMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = message.summary;
    final from = summary.from;
    return ListView(
      padding: UbaaTheme.pageInsets(context, top: 8),
      children: [
        SelectableText(summary.subject, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        DetailField(
          label: '发件人',
          value: from == null ? '—' : mailContactText(from),
        ),
        DetailField(
          label: '收件人',
          value: summary.to.isEmpty
              ? '—'
              : summary.to.map(mailContactText).join('，'),
        ),
        if (message.cc.isNotEmpty)
          DetailField(
            label: '抄送',
            value: message.cc.map(mailContactText).join('，'),
          ),
        DetailField(label: '时间', value: mailFullTime(summary.date)),
        const Divider(height: 32),
        SelectableText(
          message.text.isEmpty ? '（正文为空）' : message.text,
          style: theme.textTheme.bodyLarge,
        ),
        if (message.attachments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            '附件 ${message.attachments.length} 个',
            style: theme.textTheme.titleSmall,
          ),
          for (final attachment in message.attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(attachment.name),
              subtitle: attachment.size == null
                  ? null
                  : Text(mailSize(attachment.size)),
            ),
          const UiInfoRow(
            icon: Icons.info_outline,
            text: '附件暂时不能在 ReUBAA 里下载，请到网页版邮箱 mail.buaa.edu.cn 查看',
          ),
        ],
      ],
    );
  }
}
