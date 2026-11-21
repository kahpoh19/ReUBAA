import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'infrastructure/preferences.dart';
export 'package:ubaa_domain/ubaa_domain.dart' show ReminderNotificationSettings;

/// 交给系统定时弹出的一条本地通知，[at] 是绝对时刻。
final class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });
  final int id;
  final String title, body;
  final DateTime at;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'at': at.millisecondsSinceEpoch,
  };
}

/// 系统本地通知。排好的提醒由系统负责弹出，应用退出后照样生效。
abstract interface class NotificationGateway {
  bool get isAvailable;

  /// 申请通知权限，已经有权限时直接返回 true。
  Future<bool> requestPermission();

  /// 用 [notices] 整组替换 [group] 之前排好的提醒，传空列表就是清空。
  Future<void> replace(String group, List<ScheduledNotification> notices);

  /// 马上弹一条通知。
  Future<void> show(int id, String title, String body);
}

final class UnavailableNotificationGateway implements NotificationGateway {
  const UnavailableNotificationGateway();
  @override
  bool get isAvailable => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replace(String group, List<ScheduledNotification> notices) =>
      Future.value();
  @override
  Future<void> show(int id, String title, String body) => Future.value();
}

/// Android 和 iOS 走宿主里自己写的通道，不依赖第三方通知插件。
final class ChannelNotificationGateway implements NotificationGateway {
  ChannelNotificationGateway({MethodChannel? channel, bool? enabled})
    : _channel =
          channel ?? const MethodChannel('cn.edu.buaa.ubaa/notifications'),
      isAvailable = enabled ?? (Platform.isAndroid || Platform.isIOS);
  final MethodChannel _channel;
  @override
  final bool isAvailable;

  @override
  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> replace(String group, List<ScheduledNotification> notices) {
    if (!isAvailable) return Future.value();
    return _channel.invokeMethod<void>('replace', {
      'group': group,
      'items': [for (final n in notices) n.toJson()],
    });
  }

  @override
  Future<void> show(int id, String title, String body) {
    if (!isAvailable) return Future.value();
    return _channel.invokeMethod<void>('show', {
      'id': id,
      'title': title,
      'body': body,
    });
  }
}

/// 通知设置是设备级的普通偏好，不分账号。
final class ReminderNotificationStore {
  ReminderNotificationStore({PreferenceValues? values})
    : _values = values ?? PluginPreferenceValues();
  final PreferenceValues _values;
  static const _key = 'flutter.ubaa.notification_settings';

  Future<ReminderNotificationSettings> read() async {
    final raw = await _values.read(_key);
    if (raw == null) return const ReminderNotificationSettings();
    try {
      return ReminderNotificationSettings.fromJson(jsonDecode(raw));
    } on FormatException {
      // 存坏了就当没开过，不影响启动。
      return const ReminderNotificationSettings();
    }
  }

  Future<void> write(ReminderNotificationSettings value) =>
      _values.write(_key, jsonEncode(value.toJson()));
}
