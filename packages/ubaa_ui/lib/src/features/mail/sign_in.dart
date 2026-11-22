import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../../shared/dialogs/sheet.dart' show UiInfoRow;
import '../../shared/loading.dart' show LoadingGlyph;
import '../../theme.dart';

/// 还没登录邮箱时的说明和表单。
class MailSignInView extends StatefulWidget {
  const MailSignInView({
    required this.service,
    required this.onSignedIn,
    super.key,
  });
  final MailService service;
  final ValueChanged<MailAccount> onSignedIn;
  @override
  State<MailSignInView> createState() => _MailSignInViewState();
}

class _MailSignInViewState extends State<MailSignInView> {
  final _address = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final address = _address.text.trim();
    final password = _password.text;
    if (address.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写邮箱地址和客户端专用密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.service.signIn(address, password);
      if (mounted) widget.onSignedIn(account);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is MailException ? error.message : '登录失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: UbaaTheme.pageInsets(context),
          children: [
            Text('登录 @buaa.edu.cn 邮箱', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'ReUBAA 通过 IMAP/SMTP 收发邮件，要用 Coremail 的客户端专用密码，不是统一认证密码。',
              style: muted,
            ),
            const SizedBox(height: 16),
            const UiInfoRow(
              icon: Icons.looks_one_outlined,
              text: '用浏览器登录网页版邮箱 mail.buaa.edu.cn',
            ),
            const UiInfoRow(
              icon: Icons.looks_two_outlined,
              text: '在「设置」的客户端设置里开启 IMAP/SMTP 服务',
            ),
            const UiInfoRow(
              icon: Icons.looks_3_outlined,
              text: '在「个人设置 → 安全设置 → 客户端专用密码」里新建一个，复制到下面',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _address,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                hintText: '用户名@buaa.edu.cn',
                helperText: '只填用户名会自动补上 @buaa.edu.cn',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '客户端专用密码',
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示密码' : '隐藏密码',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const LoadingGlyph() : const Text('登录邮箱'),
            ),
            const SizedBox(height: 12),
            Text(
              '密码只存在本机的系统安全存储里，退出邮箱时会删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
