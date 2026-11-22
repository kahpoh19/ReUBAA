import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'update_tile.dart';

/// 首页顶部的新版本提示：打开应用后在后台查一次 GitHub，有新版本才显示。
///
/// 查不到、查询失败或用户忽略过这个版本时什么都不显示，不打扰。
class AppUpdateBanner extends StatefulWidget {
  const AppUpdateBanner({required this.updater, this.loadVersion, super.key});
  final AppUpdater updater;
  final Future<String?> Function()? loadVersion;

  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner> {
  AppRelease? _release;
  String? _version;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    String? version;
    AppRelease? latest;
    String? ignored;
    try {
      version = await widget.loadVersion?.call();
      latest = await widget.updater.latest(cached: true);
      ignored = await widget.updater.ignoredVersion();
    } on Object {
      // 自动检查失败不提示，关于页手动检查时再显示原因。
      return;
    }
    if (!mounted || latest == null || latest.version == ignored) return;
    if (version != null && !appVersionNewer(latest.version, version)) return;
    setState(() {
      _release = latest;
      _version = version;
    });
  }

  Future<void> _ignore(AppRelease release) async {
    setState(() => _release = null);
    try {
      await widget.updater.ignore(release.version);
    } on Object {
      // 没记住的话下次启动再提示一次。
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: const ValueKey('home-app-update'),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppUpdateTile(
              updater: widget.updater,
              currentVersion: _version,
              initialRelease: release,
              title: 'ReUBAA 有新版本',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton(
                  onPressed: () => _ignore(release),
                  child: const Text('忽略这个版本'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
