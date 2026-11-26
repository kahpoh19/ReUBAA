/// 课前自动签到的本机设置。默认隐藏且关闭，在关于页连点应用卡片十次后才出现在设置里。
final class AutoSigninSettings {
  const AutoSigninSettings({
    this.unlocked = false,
    this.enabled = false,
    this.hideFromRecents = false,
  });

  /// 课前多久开始尝试，和应用里直接签到的开放时间一致。
  static const lead = Duration(minutes: 4);

  /// 上课后多久还没签上就放弃。
  static const grace = Duration(minutes: 30);

  /// 两次尝试的间隔。
  static const interval = Duration(seconds: 30);

  /// 关于页连点多少次解锁。
  static const unlockTaps = 10;

  final bool unlocked, enabled;

  /// 从系统的最近任务里隐藏应用，免得被顺手划掉。
  final bool hideFromRecents;

  /// 功能关着时选项不显示，也不隐藏。
  bool get hidesFromRecents => enabled && hideFromRecents;

  AutoSigninSettings copyWith({
    bool? unlocked,
    bool? enabled,
    bool? hideFromRecents,
  }) => AutoSigninSettings(
    unlocked: unlocked ?? this.unlocked,
    enabled: enabled ?? this.enabled,
    hideFromRecents: hideFromRecents ?? this.hideFromRecents,
  );

  Map<String, Object> toJson() => {
    'unlocked': unlocked,
    'enabled': enabled,
    'hideFromRecents': hideFromRecents,
  };

  static AutoSigninSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['unlocked'] is! bool ||
        value['enabled'] is! bool) {
      throw const FormatException('签到设置无效');
    }
    final unlocked = value['unlocked'] as bool;
    // 没解锁时不可能是开着的，存档被改过也按关闭处理；旧存档没有隐藏这一项。
    return AutoSigninSettings(
      unlocked: unlocked,
      enabled: unlocked && value['enabled'] as bool,
      hideFromRecents: unlocked && value['hideFromRecents'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AutoSigninSettings &&
      other.unlocked == unlocked &&
      other.enabled == enabled &&
      other.hideFromRecents == hideFromRecents;

  @override
  int get hashCode => Object.hash(unlocked, enabled, hideFromRecents);
}
