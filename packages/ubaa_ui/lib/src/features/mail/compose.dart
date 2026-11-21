import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../../shared/dialogs/form_page.dart' show UiFormScaffold;
import '../../shared/loading.dart' show LoadingGlyph;
import 'format.dart';

/// 写信和回复。发送成功后返回 true。
class MailComposePage extends StatefulWidget {
  const MailComposePage({required this.service, this.replyTo, super.key});
  final MailService service;
  final MailMessage? replyTo;
  @override
  State<MailComposePage> createState() => _MailComposePageState();
}

class _MailComposePageState extends State<MailComposePage> {
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _subject = TextEditingController();
  final _text = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final original = widget.replyTo;
    if (original != null) {
      _to.text = original.summary.from?.address ?? '';
      _subject.text = mailReplySubject(original.summary.subject);
      _text.text = mailQuote(original);
    }
  }

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = mailAddresses(_to.text);
    if (to.isEmpty) {
      setState(() => _error = '请填写收件人');
      return;
    }
    if (_subject.text.trim().isEmpty && _text.text.trim().isEmpty) {
      setState(() => _error = '主题和正文不能都为空');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.send(
        MailDraft(
          to: to,
          cc: mailAddresses(_cc.text),
          subject: _subject.text.trim(),
          text: _text.text,
          replyTo: widget.replyTo,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error is MailException ? error.message : '发送失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) => UiFormScaffold(
    title: widget.replyTo == null ? '写信' : '回复',
    error: _error,
    primary: FilledButton.icon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? const LoadingGlyph(dimension: 18)
          : const Icon(Icons.send_outlined),
      label: const Text('发送'),
    ),
    children: [
      TextField(
        controller: _to,
        enabled: !_sending,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: '收件人',
          helperText: '多个地址用逗号隔开，只写用户名会补上 @buaa.edu.cn',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _cc,
        enabled: !_sending,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: '抄送（可不填）'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _subject,
        enabled: !_sending,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: '主题'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _text,
        enabled: !_sending,
        minLines: 8,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          labelText: '正文',
          alignLabelWithHint: true,
        ),
      ),
    ],
  );
}
