/// 课程提醒和待办提醒的本机设置，整台设备共用一份，默认都关闭。
///
/// 提前量统一按分钟保存，设置页再换算成分钟、小时或天显示。
final class ReminderNotificationSettings {
  const ReminderNotificationSettings({
    this.courseEnabled = false,
    this.courseLeads = defaultCourseLeads,
    this.todoEnabled = false,
    this.todoLeads = defaultTodoLeads,
  });

  /// 课前 10 分钟和 30 分钟各提醒一次。
  static const defaultCourseLeads = [10, 30];

  /// 截止前 4 小时和 1 天各提醒一次。
  static const defaultTodoLeads = [240, 1440];

  /// 设置页直接勾选的档位，其余时间用自定义添加。
  static const coursePresets = [5, 10, 15, 20, 30, 60];
  static const todoPresets = [60, 120, 240, 720, 1440, 2880, 4320];

  /// 自定义提前量最多一周，太远的提醒没什么用。
  static const maxLead = 7 * 24 * 60;

  final bool courseEnabled, todoEnabled;
  final List<int> courseLeads, todoLeads;

  ReminderNotificationSettings copyWith({
    bool? courseEnabled,
    List<int>? courseLeads,
    bool? todoEnabled,
    List<int>? todoLeads,
  }) => ReminderNotificationSettings(
    courseEnabled: courseEnabled ?? this.courseEnabled,
    courseLeads: courseLeads == null
        ? this.courseLeads
        : normalizeLeads(courseLeads),
    todoEnabled: todoEnabled ?? this.todoEnabled,
    todoLeads: todoLeads == null ? this.todoLeads : normalizeLeads(todoLeads),
  );

  /// 去重、去掉越界值并从小到大排好，存储和比较都用这个形式。
  static List<int> normalizeLeads(Iterable<int> leads) => List.unmodifiable(
    leads.where((m) => m > 0 && m <= maxLead).toSet().toList()..sort(),
  );

  Map<String, Object> toJson() => {
    'course': courseEnabled,
    'courseLeads': courseLeads,
    'todo': todoEnabled,
    'todoLeads': todoLeads,
  };

  static ReminderNotificationSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['course'] is! bool ||
        value['todo'] is! bool ||
        value['courseLeads'] is! List ||
        value['todoLeads'] is! List) {
      throw const FormatException('通知设置无效');
    }
    List<int> leads(List raw) => normalizeLeads(raw.whereType<int>());
    return ReminderNotificationSettings(
      courseEnabled: value['course'] as bool,
      courseLeads: leads(value['courseLeads'] as List),
      todoEnabled: value['todo'] as bool,
      todoLeads: leads(value['todoLeads'] as List),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderNotificationSettings &&
      other.courseEnabled == courseEnabled &&
      other.todoEnabled == todoEnabled &&
      _sameLeads(other.courseLeads, courseLeads) &&
      _sameLeads(other.todoLeads, todoLeads);

  @override
  int get hashCode => Object.hash(
    courseEnabled,
    todoEnabled,
    Object.hashAll(courseLeads),
    Object.hashAll(todoLeads),
  );
}

bool _sameLeads(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 提前量的中文写法：10 分钟、4 小时、1 天、1 天 2 小时。
String reminderLeadLabel(int minutes) {
  final days = minutes ~/ 1440,
      hours = minutes % 1440 ~/ 60,
      rest = minutes % 60;
  return [
    if (days > 0) '$days 天',
    if (hours > 0) '$hours 小时',
    if (rest > 0) '$rest 分钟',
  ].join(' ');
}
