import 'package:ubaa_ui/src/theme.dart';
import '../shared/loading.dart' show LoadingGlyph;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../common/app_links.dart' show uiShowAppLinkFailure;
import '../shared/layout/rail_identity.dart' show UiAppIcon;
import '../shared/feedback.dart';
import '../features/app_update/update_tile.dart';

class AboutView extends StatefulWidget {
  const AboutView({
    this.loadVersion,
    this.openLink,
    this.updater,
    this.onUnlockHidden,
  });
  final Future<String?> Function()? loadVersion;
  final Future<bool> Function(AppLink)? openLink;

  /// 检查更新；为空时不显示这一项。
  final AppUpdater? updater;

  /// 连点应用卡片解锁设置里的隐藏功能；已解锁或不支持时为 null，卡片不响应点按。
  final Future<void> Function()? onUnlockHidden;
  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  String? version;
  bool loading = true, opening = false;
  int _taps = 0;

  // 跟开发者选项一样，最后几下提示还差几次。
  void _tapCard() {
    final unlock = widget.onUnlockHidden;
    if (unlock == null) return;
    _taps++;
    final left = AutoSigninSettings.unlockTaps - _taps;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (left > 0) {
      if (left <= 3 && messenger != null) {
        messenger.hideCurrentSnackBar();
        UbaaFeedback.showOn(messenger, '再点 $left 次');
      }
      return;
    }
    _taps = 0;
    unawaited(unlock());
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      UbaaFeedback.showOn(
        messenger,
        '隐藏功能已出现在设置里',
        kind: UbaaFeedbackKind.success,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    setState(() => loading = true);
    String? value;
    try {
      value = await widget.loadVersion?.call();
    } on Object {
      value = null;
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      version = value;
    });
  }

  Future<void> _open(AppLink link) async {
    if (opening) return;
    setState(() => opening = true);
    var opened = false;
    try {
      opened = await widget.openLink?.call(link) ?? false;
    } on Object {
      opened = false;
    }
    if (!mounted) return;
    setState(() => opening = false);
    if (opened) return;
    await uiShowAppLinkFailure(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: UbaaTheme.pageInsets(context, top: 8),
      children: [
        Card(
          child: InkWell(
            key: const ValueKey('about-app-card'),
            onTap: widget.onUnlockHidden == null ? null : _tapCard,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const UiAppIcon(size: 64),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ReUBAA',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '校园生活助手 · 基于开源项目 UBAA 修改',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (loading && version == null)
                          const LoadingGlyph()
                        else
                          Text(
                            version == null ? '版本信息暂不可用' : '版本 $version',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (!loading && version == null && widget.loadVersion != null)
                    TextButton(
                      onPressed: _loadVersion,
                      child: const Text('重新读取版本'),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.updater case final updater?) ...[
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            // 版本读完再建，避免拿空版本比较。
            child: loading
                ? const ListTile(
                    leading: Icon(Icons.system_update_outlined),
                    title: Text('检查更新'),
                  )
                : AppUpdateTile(updater: updater, currentVersion: version),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '本软件由学生开发者制作并维护，为第三方工具，与北京航空航天大学官方无任何利益关系',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              for (final (i, link) in AppLink.values.indexed) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  enabled: !opening,
                  leading: Icon(_linkIcon(link)),
                  title: Text(link.label),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(link),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

IconData _linkIcon(AppLink link) => switch (link) {
  AppLink.project => Icons.code,
  AppLink.feedback => Icons.feedback_outlined,
  AppLink.upstream => Icons.call_split,
};
