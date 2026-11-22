import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/src/features/app_update/banner.dart';
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
  _FakeUpdater({
    this.release,
    this.canInstall = true,
    this.error,
    this.ignored,
  });
  final AppRelease? release;
  final Object? error;
  String? ignored;
  @override
  final bool canInstall;
  final opened = <AppRelease>[];
  final installs = <AppRelease>[];
  final checks = <bool>[];
  void Function(double)? progress;
  Completer<void>? download;

  @override
  Future<AppRelease?> latest({bool cached = false}) async {
    checks.add(cached);
    if (error case final error?) throw error;
    return release;
  }

  @override
  Future<String?> ignoredVersion() async => ignored;

  @override
  Future<void> ignore(String version) async => ignored = version;

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

  testWidgets('有新版本时弹出说明，安卓下载时显示进度，系统要求确认时提示', (tester) async {
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

    updater.progress!(1);
    await tester.pump();
    expect(find.text('下载完成，正在安装，完成后应用会自动关闭'), findsOneWidget);

    updater.download!.complete();
    await tester.pumpAndSettle();
    expect(updater.installs, [_release]);
    expect(find.text('请在系统弹出的窗口里确认安装'), findsOneWidget);
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

  testWidgets('首页启动时用缓存查一次，有新版本才提示，可以忽略这个版本', (tester) async {
    Future<void> home(AppUpdater updater, {String? version = '1.1.0+2032'}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppUpdateBanner(
                updater: updater,
                loadVersion: () async => version,
              ),
            ),
          ),
        );

    final updater = _FakeUpdater(release: _release);
    await home(updater);
    await tester.pumpAndSettle();
    expect(updater.checks, [true]);
    expect(find.text('ReUBAA 有新版本'), findsOneWidget);
    expect(find.text('发现新版本 1.2.0'), findsOneWidget);

    // 点提示直接弹出更新说明，不用再查一次。
    await tester.tap(find.text('ReUBAA 有新版本'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-update-dialog')), findsOneWidget);
    expect(updater.checks, [true]);
    await tester.tap(find.text('以后再说'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('忽略这个版本'));
    await tester.pumpAndSettle();
    expect(updater.ignored, '1.2.0');
    expect(find.text('ReUBAA 有新版本'), findsNothing);

    // 忽略过的版本、已经是最新、查询失败时都不显示。
    for (final (quiet, version) in [
      (_FakeUpdater(release: _release, ignored: '1.2.0'), '1.1.0'),
      (_FakeUpdater(release: _release), '1.2.0+2040'),
      (
        _FakeUpdater(error: const AppUpdateException(AppUpdateFailure.network)),
        '1.1.0',
      ),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await home(quiet, version: version);
      await tester.pumpAndSettle();
      expect(find.text('ReUBAA 有新版本'), findsNothing);
    }
  });
}
