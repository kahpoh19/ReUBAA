import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/src/features/app_update/update_tile.dart';

final _release = AppRelease(
  version: '1.2.0',
  title: 'ReUBAA 1.2.0',
  notes: '修复了一些问题',
  page: Uri.parse(
    'https://github.com/kahpoh19/ReUBAA/releases/tag/reubaa-v1.2.0',
  ),
  asset: AppReleaseAsset(
    name: 'ReUBAA-1.2.0-android-arm64-v8a.apk',
    url: Uri.parse('https://github.com/download/arm64.apk'),
    size: 42 * 1024 * 1024,
  ),
);

/// 假的更新源，下载进度由测试一步步推进。
class _FakeUpdater implements AppUpdater {
  _FakeUpdater({this.release, this.canInstall = true, this.error});
  final AppRelease? release;
  final Object? error;
  @override
  final bool canInstall;
  final opened = <AppRelease>[];
  final installs = <AppRelease>[];
  void Function(double)? progress;
  Completer<void>? download;

  @override
  Future<AppRelease?> latest() async {
    if (error case final error?) throw error;
    return release;
  }

  @override
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) {
    installs.add(release);
    progress = onProgress;
    return (download = Completer<void>()).future;
  }

  @override
  Future<bool> openPage(AppRelease release) async {
    opened.add(release);
    return true;
  }
}

Future<void> _pump(WidgetTester tester, AppUpdater updater) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppUpdateTile(updater: updater, currentVersion: '1.1.0+2032'),
      ),
    ),
  );
}

void main() {
  testWidgets('最新版本和当前一致时提示已是最新', (tester) async {
    await _pump(
      tester,
      _FakeUpdater(
        release: AppRelease(
          version: '1.1.0',
          title: 'ReUBAA 1.1.0',
          notes: '',
          page: Uri.parse('https://github.com'),
        ),
      ),
    );
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-update-dialog')), findsNothing);
  });

  testWidgets('有新版本时弹出说明，安卓下载时显示进度并调起安装器', (tester) async {
    final updater = _FakeUpdater(release: _release);
    await _pump(tester, updater);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 1.2.0'), findsWidgets);
    expect(find.textContaining('修复了一些问题'), findsOneWidget);
    expect(find.textContaining('42.0 MB'), findsOneWidget);

    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    updater.progress!(0.42);
    await tester.pump();
    expect(find.text('正在下载 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    updater.download!.complete();
    await tester.pumpAndSettle();
    expect(updater.installs, [_release]);
    expect(find.text('已打开系统安装器，按提示完成更新'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('不能应用内安装时打开 Release 页面', (tester) async {
    final updater = _FakeUpdater(release: _release, canInstall: false);
    await _pump(tester, updater);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('前往下载'));
    await tester.pumpAndSettle();
    expect(updater.opened, [_release]);
    expect(updater.installs, isEmpty);
  });

  testWidgets('检查失败和缺少安装权限时显示原因', (tester) async {
    await _pump(
      tester,
      _FakeUpdater(
        error: const AppUpdateException(AppUpdateFailure.rateLimited),
      ),
    );
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('限制了查询次数'), findsOneWidget);

    // 换一个更新源要先卸掉旧组件，否则状态会沿用。
    final updater = _FakeUpdater(release: _release);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, updater);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    updater.download!.completeError(
      const AppUpdateException(AppUpdateFailure.installPermission),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('允许 ReUBAA 安装应用'), findsOneWidget);
  });
}
