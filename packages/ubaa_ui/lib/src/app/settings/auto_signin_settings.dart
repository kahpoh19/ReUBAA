import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/feedback.dart';

/// 设置页“实验功能”分组：课前自动签到和它需要的后台运行权限。
///
/// 只有在关于页解锁后宿主才会提供，未解锁时为 null，整个分组不显示。
final class UiAutoSigninControls {
  const UiAutoSigninControls({
    required this.enabled,
    required this.onChanged,
    required this.onHide,
    this.batteryUnrestricted,
    this.onRequestUnrestricted,
    this.onOpenAutostart,
    this.status,
    this.note,
  });
  final bool enabled;
  final Future<void> Function(bool enabled) onChanged;

  /// 重新隐藏分组，同时关闭功能。
  final Future<void> Function() onHide;

  /// Android 上是否已忽略电池优化；其他平台为 null，不显示后台运行条目。
  final bool? batteryUnrestricted;
  final VoidCallback? onRequestUnrestricted, onOpenAutostart;

  /// 最近一次签到的结果。
  final String? status;

  /// 平台限制说明。
  final String? note;
}

class AutoSigninPanel extends StatelessWidget {
  const AutoSigninPanel({super.key, required this.controls});
  final UiAutoSigninControls controls;

  Future<void> _set(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await controls.onChanged(value);
    } on Object {
      if (messenger != null) {
        UbaaFeedback.showOn(
          messenger,
          '设置未能保存，请重试',
          kind: UbaaFeedbackKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final battery = controls.batteryUnrestricted;
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('settings-auto-signin'),
          secondary: const Icon(Icons.how_to_reg_outlined),
          title: const Text('课前自动签到'),
          subtitle: const Text('上课前 5 分钟起每 30 秒尝试一次，签上或上课 30 分钟后停止'),
          value: controls.enabled,
          onChanged: (value) => unawaited(_set(context, value)),
        ),
        if (controls.status case final status?)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(status),
            dense: true,
          ),
        if (controls.enabled && battery != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              battery ? Icons.battery_full : Icons.battery_alert_outlined,
            ),
            title: const Text('忽略电池优化'),
            subtitle: Text(battery ? '已允许后台运行' : '未开启时熄屏后可能无法按时签到'),
            trailing: battery
                ? const Icon(Icons.check)
                : TextButton(
                    onPressed: controls.onRequestUnrestricted,
                    child: const Text('去开启'),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('自启动与后台运行'),
            subtitle: const Text('小米、OPPO、vivo、华为等需要在系统设置里手动允许'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: controls.onOpenAutostart,
          ),
        ],
        if (controls.note case final note?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}
