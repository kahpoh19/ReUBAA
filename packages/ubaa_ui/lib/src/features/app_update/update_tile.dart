import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

/// 关于页的“检查更新”：点一下查 GitHub 最新正式版，有新版本时弹出说明，
/// 安卓在应用内下载后调起系统安装器，其他平台打开 Release 页面。
class AppUpdateTile extends StatefulWidget {
  const AppUpdateTile({required this.updater, this.currentVersion, super.key});
  final AppUpdater updater;

  /// 当前安装的版本，如 `1.1.0+2032`；读不到时任何正式版都算新版本。
  final String? currentVersion;

  @override
  State<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends State<AppUpdateTile> {
  bool _checking = false;
  AppRelease? _release;
  bool _upToDate = false;

  /// 下载进度，为 null 时没在下载。
  double? _progress;
  bool _installerOpened = false;
  String? _error;

  bool get _busy => _checking || _progress != null;

  Future<void> _tap() async {
    final release = _release;
    if (release != null) return _offer(release);
    setState(() {
      _checking = true;
      _upToDate = false;
      _error = null;
    });
    AppRelease? latest;
    try {
      latest = await widget.updater.latest();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _describe(error);
      });
      return;
    }
    if (!mounted) return;
    final current = widget.currentVersion;
    final newer =
        latest != null &&
        (current == null || appVersionNewer(latest.version, current));
    setState(() {
      _checking = false;
      _release = newer ? latest : null;
      _upToDate = !newer;
    });
    if (newer) await _offer(latest);
  }

  Future<void> _offer(AppRelease release) async {
    final install = widget.updater.canInstall && release.asset != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('app-update-dialog'),
        title: Text('发现新版本 ${release.version}'),
        scrollable: true,
        content: Text(
          [
            if (widget.currentVersion != null) '当前版本 ${widget.currentVersion}',
            if (install) '安装包 ${_size(release.asset!.size)}，从 GitHub 下载。',
            if (release.notes.trim().isNotEmpty) release.notes.trim(),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('以后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(install ? '下载并安装' : '前往下载'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!install) {
      await widget.updater.openPage(release);
      return;
    }
    setState(() {
      _progress = 0;
      _installerOpened = false;
      _error = null;
    });
    try {
      await widget.updater.install(
        release,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) setState(() => _installerOpened = true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  static String _describe(Object error) =>
      error is AppUpdateException ? error.message : '检查更新失败，请稍后重试';

  static String _size(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _progress;
    final release = _release;
    final subtitle = _checking
        ? '正在检查…'
        : progress != null
        ? '正在下载 ${(progress * 100).floor()}%'
        : _error ??
              (_installerOpened
                  ? '已打开系统安装器，按提示完成更新'
                  : release != null
                  ? '发现新版本 ${release.version}'
                  : _upToDate
                  ? '已是最新版本'
                  : '从 GitHub Releases 获取新版本');
    return ListTile(
      key: const ValueKey('app-update-tile'),
      enabled: !_busy,
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('检查更新'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: _error != null
                ? TextStyle(color: colors.error)
                : release != null && progress == null
                ? TextStyle(color: colors.primary)
                : null,
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
      trailing: release != null && !_busy
          ? Icon(Icons.circle, size: 10, color: colors.primary)
          : null,
      onTap: _tap,
    );
  }
}
