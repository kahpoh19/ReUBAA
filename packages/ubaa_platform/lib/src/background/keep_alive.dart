import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../infrastructure/preferences.dart';
export 'package:ubaa_domain/ubaa_domain.dart' show AutoSigninSettings;

/// 让应用在后台按时醒来。只有 Android 能做到：前台服务常驻、精确闹钟唤醒、
/// 开机自动拉起；iOS 系统不允许应用常驻后台，这里一律不可用。
abstract interface class KeepAliveGateway {
  bool get isAvailable;

  /// 闹钟把应用叫醒时发一个事件。
  Stream<void> get wakes;

  /// 打开后启动常驻服务并在开机时自动拉起，关闭后停掉。
  Future<void> setEnabled(bool enabled);

  /// 用 [times] 替换之前的全部唤醒时刻。
  Future<void> scheduleWakes(List<DateTime> times);

  /// 一轮任务做完，释放唤醒锁让手机休眠。
  Future<void> release();

  /// 是否已忽略电池优化；平台不支持时为 null。
  Future<bool?> batteryUnrestricted();

  Future<void> requestUnrestricted();

  /// 尽量打开厂商的自启动管理页，找不到就打开应用详情页。
  Future<void> openAutostartSettings();

  /// 从系统的最近任务里隐藏应用；从桌面图标打开不受影响。
  Future<void> setHiddenFromRecents(bool hidden);
}

final class UnavailableKeepAliveGateway implements KeepAliveGateway {
  const UnavailableKeepAliveGateway();
  @override
  bool get isAvailable => false;
  @override
  Stream<void> get wakes => const Stream.empty();
  @override
  Future<void> setEnabled(bool enabled) => Future.value();
  @override
  Future<void> scheduleWakes(List<DateTime> times) => Future.value();
  @override
  Future<void> release() => Future.value();
  @override
  Future<bool?> batteryUnrestricted() async => null;
  @override
  Future<void> requestUnrestricted() => Future.value();
  @override
  Future<void> openAutostartSettings() => Future.value();
  @override
  Future<void> setHiddenFromRecents(bool hidden) => Future.value();
}

final class ChannelKeepAliveGateway implements KeepAliveGateway {
  ChannelKeepAliveGateway({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('cn.edu.buaa.ubaa/keep-alive'),
      isAvailable = enabled ?? Platform.isAndroid {
    if (isAvailable) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'wake') _wakes.add(null);
      });
    }
  }
  final MethodChannel _channel;
  final _wakes = StreamController<void>.broadcast();
  @override
  final bool isAvailable;

  @override
  Stream<void> get wakes => _wakes.stream;

  @override
  Future<void> setEnabled(bool enabled) => isAvailable
      ? _channel.invokeMethod<void>('setEnabled', enabled)
      : Future.value();

  @override
  Future<void> scheduleWakes(List<DateTime> times) => isAvailable
      ? _channel.invokeMethod<void>('scheduleWakes', [
          for (final t in times) t.millisecondsSinceEpoch,
        ])
      : Future.value();

  @override
  Future<void> release() =>
      isAvailable ? _channel.invokeMethod<void>('release') : Future.value();

  @override
  Future<bool?> batteryUnrestricted() async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod<bool>('batteryUnrestricted');
    } on Object {
      return null;
    }
  }

  @override
  Future<void> requestUnrestricted() => isAvailable
      ? _channel.invokeMethod<void>('requestUnrestricted')
      : Future.value();

  @override
  Future<void> openAutostartSettings() => isAvailable
      ? _channel.invokeMethod<void>('openAutostart')
      : Future.value();

  @override
  Future<void> setHiddenFromRecents(bool hidden) => isAvailable
      ? _channel.invokeMethod<void>('setHiddenFromRecents', hidden)
      : Future.value();
}

/// 自动签到设置也是设备级普通偏好。
final class AutoSigninStore {
  AutoSigninStore({PreferenceValues? values})
    : _values = values ?? PluginPreferenceValues();
  final PreferenceValues _values;
  static const _key = 'flutter.ubaa.course_assist';

  Future<AutoSigninSettings> read() async {
    final raw = await _values.read(_key);
    if (raw == null) return const AutoSigninSettings();
    try {
      return AutoSigninSettings.fromJson(jsonDecode(raw));
    } on FormatException {
      return const AutoSigninSettings();
    }
  }

  Future<void> write(AutoSigninSettings value) =>
      _values.write(_key, jsonEncode(value.toJson()));
}
