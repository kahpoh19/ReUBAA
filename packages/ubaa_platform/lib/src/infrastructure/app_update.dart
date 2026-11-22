import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

import '../app_information.dart' show openExternalUrl;

/// 从本仓库 GitHub Releases 检查更新。安卓下载对应架构的 APK 后交给系统安装器，
/// 其他平台只打开 Release 页面。
///
/// 只用 GitHub 公开接口，不带任何账号；未登录每小时有 60 次的查询限制。
final class GithubAppUpdater implements AppUpdater {
  GithubAppUpdater({MethodChannel? channel, bool? android})
    : _channel = channel ?? const MethodChannel('cn.edu.buaa.ubaa/app-update'),
      canInstall = android ?? Platform.isAndroid;

  static final latestApi = Uri.parse(
    'https://api.github.com/repos/kahpoh19/ReUBAA/releases/latest',
  );

  final MethodChannel _channel;
  @override
  final bool canInstall;

  @override
  Future<AppRelease?> latest() async {
    final abi = canInstall ? await _channel.invokeMethod<String>('abi') : null;
    final client = HttpClient()..userAgent = 'ReUBAA';
    try {
      final request = await client.getUrl(latestApi);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      // 仓库还没有正式版时接口返回 404。
      if (response.statusCode == 404) return null;
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const AppUpdateException(AppUpdateFailure.rateLimited);
      }
      if (response.statusCode != 200) {
        throw const AppUpdateException(AppUpdateFailure.network);
      }
      return parseGithubRelease(
        jsonDecode(body) as Map<String, Object?>,
        abi: abi,
      );
    } on IOException {
      throw const AppUpdateException(AppUpdateFailure.network);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final asset = release.asset!;
    if (await _channel.invokeMethod<bool>('canInstall') != true) {
      await _channel.invokeMethod<void>('openInstallSettings');
      throw const AppUpdateException(AppUpdateFailure.installPermission);
    }
    final directory = Directory(
      (await _channel.invokeMethod<String>('directory'))!,
    );
    // 每次只留这一个安装包，旧版本下载的直接删掉。
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    final file = File('${directory.path}/${asset.name}');
    await _download(asset, file, onProgress);
    await _channel.invokeMethod<void>('install', file.path);
  }

  Future<void> _download(
    AppReleaseAsset asset,
    File file,
    void Function(double progress)? onProgress,
  ) async {
    final client = HttpClient()..userAgent = 'ReUBAA';
    try {
      final response = await (await client.getUrl(asset.url)).close();
      if (response.statusCode != 200) {
        throw const AppUpdateException(AppUpdateFailure.network);
      }
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (asset.size > 0) onProgress?.call(received / asset.size);
        }
      } finally {
        await sink.close();
      }
      if (received != asset.size) {
        throw const AppUpdateException(AppUpdateFailure.corrupted);
      }
    } on IOException {
      throw const AppUpdateException(AppUpdateFailure.network);
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> openPage(AppRelease release) => openExternalUrl(release.page);
}

/// 解析 GitHub 的 Release 接口；[abi] 是本机首选架构，有对应 APK 时作为安装包。
AppRelease parseGithubRelease(Map<String, Object?> json, {String? abi}) {
  final tag = json['tag_name'] as String;
  final assets = (json['assets'] as List<Object?>? ?? const [])
      .cast<Map<String, Object?>>();
  final apk = abi == null
      ? null
      : assets
            .where((a) => (a['name'] as String).endsWith('-android-$abi.apk'))
            .firstOrNull;
  return AppRelease(
    version: appVersionOf(tag) ?? tag,
    title: (json['name'] as String?)?.trim().isNotEmpty == true
        ? json['name'] as String
        : tag,
    notes: json['body'] as String? ?? '',
    page: Uri.parse(json['html_url'] as String? ?? appReleasesUrl),
    asset: apk == null
        ? null
        : AppReleaseAsset(
            name: apk['name'] as String,
            url: Uri.parse(apk['browser_download_url'] as String),
            size: apk['size'] as int,
          ),
  );
}
