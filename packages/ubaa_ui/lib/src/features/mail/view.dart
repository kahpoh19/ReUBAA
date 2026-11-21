import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../../common/chip_strip.dart';
import '../../common/state_panel.dart';
import '../../shared/dialogs/confirmation.dart' show uiConfirmIrreversible;
import '../../shared/dialogs/form_page.dart' show showUiPage;
import '../../shared/feedback.dart';
import '../../shared/infinite_scroll.dart';
import '../../shared/loading.dart';
import '../../shared/refresh.dart';
import '../../theme.dart';
import 'compose.dart';
import 'format.dart';
import 'reader.dart';
import 'sign_in.dart';

export 'format.dart' show mailTitle;

/// 北航邮箱：没登录时显示登录说明，登录后按文件夹看信、写信。
///
/// 邮箱账号和 ReUBAA 的统一认证账号分开保存，切换校园账号不影响邮箱。
class MailView extends StatefulWidget {
  const MailView({required this.service, super.key});
  final MailService service;
  @override
  State<MailView> createState() => _MailViewState();
}

class _MailViewState extends State<MailView> {
  MailAccount? _account;
  bool _checking = true;
  List<MailFolder> _folders = const [];
  String? _folder;
  List<MailSummary> _messages = const [];
  int? _nextBefore;
  bool _loaded = false, _loading = false, _loadingMore = false;
  String? _error, _moreError;

  /// 换文件夹、刷新或退出后，丢掉还没回来的旧请求结果。
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    MailAccount? account;
    try {
      account = await widget.service.account();
    } on Object {
      // 读不到保存的账号就当没登录，重新登录会覆盖。
    }
    if (!mounted) return;
    setState(() {
      _account = account;
      _checking = false;
    });
    if (account != null) await _load();
  }

  static String _describe(Object error) =>
      error is MailException ? error.message : '读取失败，请稍后重试';

  /// 刷新文件夹和当前文件夹的第一页；传入 [folder] 时切到那个文件夹。
  Future<void> _load([String? folder]) async {
    final revision = ++_revision;
    setState(() {
      if (folder != null && folder != _folder) {
        _folder = folder;
        _messages = const [];
        _nextBefore = null;
        _loaded = false;
      }
      _loading = true;
      _loadingMore = false;
      _error = null;
      _moreError = null;
    });
    bool current() => mounted && revision == _revision;
    try {
      final folders = await widget.service.folders();
      final path =
          folder ??
          (folders.any((f) => f.path == _folder)
              ? _folder!
              : folders.firstOrNull?.path ?? 'INBOX');
      final page = await widget.service.list(path);
      if (!current()) return;
      setState(() {
        _folders = folders;
        _folder = path;
        _messages = page.messages;
        _nextBefore = page.nextBefore;
        _loaded = true;
      });
    } on Object catch (error) {
      if (current()) setState(() => _error = _describe(error));
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final folder = _folder;
    final before = _nextBefore;
    if (folder == null || before == null || _loading || _loadingMore) return;
    final revision = _revision;
    bool current() => mounted && revision == _revision;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await widget.service.list(folder, before: before);
      if (!current()) return;
      setState(() {
        _messages = [..._messages, ...page.messages];
        _nextBefore = page.nextBefore;
      });
    } on Object catch (error) {
      if (current()) setState(() => _moreError = _describe(error));
    } finally {
      if (current()) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(MailSummary summary) async {
    if (!summary.seen) {
      // 读信时服务器会标已读，列表先跟着变，不用整页刷新。
      setState(
        () => _messages = [
          for (final m in _messages) identical(m, summary) ? _seen(m) : m,
        ],
      );
    }
    await showUiPage<void>(
      context,
      fixedHeight: true,
      builder: (_) => MailReaderPage(
        service: widget.service,
        summary: summary,
        onReply: _compose,
      ),
    );
  }

  Future<void> _compose([MailMessage? replyTo]) async {
    final sent = await showUiPage<bool>(
      context,
      builder: (_) =>
          MailComposePage(service: widget.service, replyTo: replyTo),
    );
    if (sent != true || !mounted) return;
    UbaaFeedback.show(context, '邮件已发送', kind: UbaaFeedbackKind.success);
    if (_folders.any(
      (f) => f.path == _folder && f.kind == MailFolderKind.sent,
    )) {
      unawaited(_load());
    }
  }

  Future<void> _signOut() async {
    final confirmed = await uiConfirmIrreversible(
      context,
      title: '退出邮箱',
      message: '会删除本机保存的客户端专用密码，下次需要重新输入。',
      action: '退出',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.service.signOut();
    } on Object {
      // 删除失败下次登录时会覆盖，这里照常回到登录页。
    }
    if (!mounted) return;
    setState(() {
      _revision++;
      _account = null;
      _folders = const [];
      _folder = null;
      _messages = const [];
      _nextBefore = null;
      _loaded = _loading = _loadingMore = false;
      _error = _moreError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const LoadingPlaceholder();
    final account = _account;
    if (account == null) {
      return MailSignInView(
        service: widget.service,
        onSignedIn: (account) {
          setState(() => _account = account);
          unawaited(_load());
        },
      );
    }
    final folder = _folders.where((f) => f.path == _folder).firstOrNull;
    final outgoing =
        folder?.kind == MailFolderKind.sent ||
        folder?.kind == MailFolderKind.drafts;
    return PullToRefresh(
      onRefresh: _load,
      child: InfiniteScroll(
        onLoadMore: _loadMore,
        loading: _loadingMore,
        error: _moreError,
        hasMore: _nextBefore != null,
        child: ListView(
          key: const PageStorageKey<String>('mail-page'),
          padding: UbaaTheme.pageInsets(context, top: 8),
          children: [
            _MailHeader(
              address: account.address,
              loading: _loading,
              onRefresh: _load,
              onCompose: _compose,
              onSignOut: _signOut,
            ),
            if (_folders.length > 1) ...[
              const SizedBox(height: 8),
              UiChipStrip(
                spacing: 8,
                bleed: true,
                children: [
                  for (final f in _folders)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: f.path == _folder,
                      onSelected: (_) => _load(f.path),
                    ),
                ],
              ),
            ],
            if (_loaded && _error != null) ...[
              const SizedBox(height: 8),
              UiInlineRetry(
                message: '刷新失败：$_error',
                onRetry: _loading ? null : _load,
              ),
            ],
            const SizedBox(height: 8),
            if (!_loaded)
              _error != null
                  ? UiStatePanel(
                      compact: true,
                      icon: Icons.cloud_off_outlined,
                      title: '邮件读取失败',
                      detail: _error,
                      action: '重试',
                      actionIcon: Icons.refresh,
                      onAction: _load,
                    )
                  : const LoadingPlaceholder(compact: true)
            else if (_messages.isEmpty)
              const UiStatePanel(
                compact: true,
                icon: Icons.inbox_outlined,
                title: '这里没有邮件',
              )
            else
              for (final m in _messages)
                _MailTile(
                  key: ValueKey('mail-${m.folder}-${m.uid}'),
                  summary: m,
                  outgoing: outgoing,
                  onTap: () => _open(m),
                ),
          ],
        ),
      ),
    );
  }
}

MailSummary _seen(MailSummary m) => MailSummary(
  uid: m.uid,
  folder: m.folder,
  subject: m.subject,
  from: m.from,
  to: m.to,
  date: m.date,
  hasAttachments: m.hasAttachments,
);

class _MailHeader extends StatelessWidget {
  const _MailHeader({
    required this.address,
    required this.loading,
    required this.onRefresh,
    required this.onCompose,
    required this.onSignOut,
  });
  final String address;
  final bool loading;
  final VoidCallback onRefresh, onCompose, onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: loading ? null : onRefresh,
          icon: loading ? const LoadingGlyph() : const Icon(Icons.refresh),
        ),
        PopupMenuButton<void>(
          tooltip: '更多',
          itemBuilder: (_) => [
            PopupMenuItem(onTap: onSignOut, child: const Text('退出邮箱')),
          ],
        ),
        const SizedBox(width: 4),
        FilledButton.tonalIcon(
          onPressed: onCompose,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('写信'),
        ),
      ],
    );
  }
}

class _MailTile extends StatelessWidget {
  const _MailTile({
    required this.summary,
    required this.outgoing,
    required this.onTap,
    super.key,
  });
  final MailSummary summary;

  /// 已发送和草稿箱里显示收件人，其余显示发件人。
  final bool outgoing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = !summary.seen;
    final who = outgoing
        ? summary.to.isEmpty
              ? '（没有收件人）'
              : '发给 ${summary.to.map((c) => c.label).join('、')}'
        : summary.from?.label ?? '（未知发件人）';
    final initial = who.characters.firstOrNull ?? '?';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: unread
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        foregroundColor: unread
            ? colors.onPrimaryContainer
            : colors.onSurfaceVariant,
        child: Text(outgoing ? '发' : initial),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: unread
                  ? const TextStyle(fontWeight: FontWeight.w600)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            mailListTime(summary.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: unread ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              summary.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: unread ? TextStyle(color: colors.onSurface) : null,
            ),
          ),
          if (summary.hasAttachments) ...[
            const SizedBox(width: 4),
            Icon(Icons.attach_file, size: 16, color: colors.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}
