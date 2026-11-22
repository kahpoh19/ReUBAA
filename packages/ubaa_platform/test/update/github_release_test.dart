import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

Map<String, Object?> _release({String? name = 'ReUBAA 1.2.0'}) => {
  'tag_name': 'reubaa-v1.2.0',
  'name': name,
  'body': '安装说明',
  'html_url': 'https://github.com/kahpoh19/ReUBAA/releases/tag/reubaa-v1.2.0',
  'assets': [
    for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
      {
        'name': 'ReUBAA-1.2.0-android-$abi.apk',
        'browser_download_url': 'https://github.com/download/$abi.apk',
        'size': 40000000,
      },
    {
      'name': 'ReUBAA-1.2.0-windows-x64.exe',
      'browser_download_url': 'https://github.com/download/win.exe',
      'size': 36000000,
    },
  ],
};

void main() {
  test('按本机架构挑 APK，Tag 去掉前缀作为版本号', () {
    final release = parseGithubRelease(_release(), abi: 'armeabi-v7a');
    expect(release.version, '1.2.0');
    expect(release.title, 'ReUBAA 1.2.0');
    expect(release.notes, '安装说明');
    expect(release.asset?.name, 'ReUBAA-1.2.0-android-armeabi-v7a.apk');
    expect(release.asset?.size, 40000000);
    expect(release.page.path, '/kahpoh19/ReUBAA/releases/tag/reubaa-v1.2.0');
  });

  test('没有架构或没有对应 APK 时不给安装包，标题为空时用 Tag', () {
    expect(parseGithubRelease(_release()).asset, isNull);
    expect(parseGithubRelease(_release(), abi: 'riscv64').asset, isNull);
    expect(parseGithubRelease(_release(name: ' ')).title, 'reubaa-v1.2.0');
  });

  test('版本比较只看数字部分，构建号不影响', () {
    expect(appVersionOf('reubaa-v1.2.0'), '1.2.0');
    expect(appVersionOf('1.1.0+2032'), '1.1.0');
    expect(appVersionNewer('1.2.0', '1.1.0+2032'), isTrue);
    expect(appVersionNewer('1.10.0', '1.9.3'), isTrue);
    expect(appVersionNewer('1.1', '1.1.0+2033'), isFalse);
    expect(appVersionNewer('1.1.0', '1.1.0+2032'), isFalse);
    expect(appVersionNewer('1.0.9', '1.1.0'), isFalse);
  });

  test('忽略的版本存在普通偏好里', () async {
    final preferences = MemoryPreferenceValues();
    final updater = GithubAppUpdater(android: false, preferences: preferences);
    expect(await updater.ignoredVersion(), isNull);
    await updater.ignore('1.2.0');
    expect(await updater.ignoredVersion(), '1.2.0');
    expect(
      await GithubAppUpdater(
        android: false,
        preferences: preferences,
      ).ignoredVersion(),
      '1.2.0',
    );
  });
}
