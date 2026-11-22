/// ReUBAA 自己的检查更新：读本仓库 GitHub Releases 的最新正式版。
///
/// 和原版走应用服务的更新提示分开，原版那套在 ReUBAA 的构建里没有服务地址。
library;

/// 本仓库的 Releases 页面，不能应用内安装时打开这里。
const appReleasesUrl = 'https://github.com/kahpoh19/ReUBAA/releases/latest';

/// Release 里的一个安装包。
final class AppReleaseAsset {
  const AppReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });
  final String name;
  final Uri url;
  final int size;
}

/// 一个 GitHub Release。
final class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.notes,
    required this.page,
    this.asset,
  });

  /// 从 Tag 里取出的版本号，如 `reubaa-v1.2.0` 得到 `1.2.0`。
  final String version;
  final String title;
  final String notes;
  final Uri page;

  /// 适合本机的安装包；没有时只能打开 [page] 手动下载。
  final AppReleaseAsset? asset;
}

enum AppUpdateFailure {
  /// 网络不通或 GitHub 访问失败。
  network,

  /// 未登录访问 GitHub 接口有每小时次数限制。
  rateLimited,

  /// 没有安装未知应用的权限，已经打开了系统设置页。
  installPermission,

  /// 下载的文件和 Release 里写的大小不一致。
  corrupted,
}

final class AppUpdateException implements Exception {
  const AppUpdateException(this.failure);
  final AppUpdateFailure failure;

  String get message => switch (failure) {
    AppUpdateFailure.network => '连接 GitHub 失败，请检查网络后重试',
    AppUpdateFailure.rateLimited => 'GitHub 暂时限制了查询次数，请过一会再试',
    AppUpdateFailure.installPermission => '请在打开的设置页允许 ReUBAA 安装应用，返回后再点一次',
    AppUpdateFailure.corrupted => '安装包下载不完整，请重试',
  };

  @override
  String toString() => 'AppUpdateException($failure)';
}

abstract interface class AppUpdater {
  /// 最新的正式版 Release；仓库还没有 Release 时为 null。
  Future<AppRelease?> latest();

  /// 能否在应用内下载并调起系统安装（目前只有安卓）。
  bool get canInstall;

  /// 下载 [release] 的安装包并交给系统安装器。
  ///
  /// [onProgress] 收到 0～1 的下载进度。
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  });

  /// 用浏览器打开 Release 页面。
  Future<bool> openPage(AppRelease release);
}

/// 从 Tag 或版本字符串里取出数字版本，如 `reubaa-v1.2.0`、`1.2.0+2033` 都得到 `1.2.0`。
String? appVersionOf(String text) =>
    RegExp(r'\d+(\.\d+)*').firstMatch(text)?.group(0);

/// [latest] 是否比 [current] 新，只比较点分的数字部分。
bool appVersionNewer(String latest, String current) {
  final a = (appVersionOf(latest) ?? '').split('.');
  final b = (appVersionOf(current) ?? '').split('.');
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? int.tryParse(a[i]) ?? 0 : 0;
    final y = i < b.length ? int.tryParse(b[i]) ?? 0 : 0;
    if (x != y) return x > y;
  }
  return false;
}
