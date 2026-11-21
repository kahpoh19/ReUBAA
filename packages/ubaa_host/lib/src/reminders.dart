part of 'ubaa_app_host.dart';

/// 原生侧按分组整组替换提醒，课程和待办分开排。
const _courseNoticeGroup = 'course';
const _todoNoticeGroup = 'todo';

/// iOS 最多同时排 64 条本地通知，留几条给课前签到提醒；Android 也没必要排更多。
const _maxScheduledNotices = 56;

extension _UbaaAppHostReminders on _UbaaAppHostState {
  UiNotificationControls? get _notificationControls {
    if (!_notifications.isAvailable) return null;
    return UiNotificationControls(
      settings: _notificationSettings,
      onChanged: _setNotificationSettings,
      note: Platform.isIOS ? 'iOS 只能提前排好最近几天的提醒，隔几天打开一次应用即可续上' : null,
    );
  }

  Future<void> _loadNotificationSettings() async {
    var value = const ReminderNotificationSettings();
    try {
      value = await _notificationStore.read();
    } on Object {
      // 读不到就按默认关闭处理。
    }
    if (_disposed) return;
    _refreshHost(() {
      _notificationSettings = value;
      _notificationSettingsLoaded = true;
    });
    _syncReminders();
  }

  Future<void> _setNotificationSettings(
    ReminderNotificationSettings value,
  ) async {
    final before = _notificationSettings;
    final turningOn =
        (value.courseEnabled && !before.courseEnabled) ||
        (value.todoEnabled && !before.todoEnabled);
    if (turningOn && !await _notifications.requestPermission()) {
      final messenger = _messengerKey.currentState;
      if (messenger != null) {
        UbaaFeedback.showOn(
          messenger,
          '没有通知权限，请先在系统设置里允许 ReUBAA 发送通知',
          kind: UbaaFeedbackKind.warning,
        );
      }
      return;
    }
    _refreshHost(() => _notificationSettings = value);
    try {
      await _notificationStore.write(value);
    } on Object {
      _refreshHost(() => _notificationSettings = before);
      rethrow;
    }
    _syncReminders();
  }

  /// 控制器每次通知都会进来，只有输入真的变了才重新排。
  void _syncReminders() {
    if (_disposed ||
        _readyController == null ||
        !_notificationSettingsLoaded ||
        !_notifications.isAvailable)
      return;
    final settings = _notificationSettings;
    final home = _controller.homeState;
    final schedule = (
      _controller.scheduleWidgetRevision,
      _controller.agendaProjectionEpoch,
    );
    final todos = Object.hashAll(home.todos.map((t) => (t.id, t.deadline)));
    final stamp = (
      _controller.scheduleWidgetOwner,
      settings,
      settings.courseEnabled ? schedule : null,
      settings.todoEnabled && home.projected ? todos : null,
      _reminderRound,
    );
    if (stamp == _reminderStamp) return;
    _reminderStamp = stamp;
    _reminderDelay?.cancel();
    // 首页刷新会连着通知好多次，等安静两秒再排。
    _reminderDelay = Timer(
      const Duration(seconds: 2),
      () => unawaited(_rescheduleReminders()),
    );
  }

  Future<void> _rescheduleReminders() async {
    final generation = ++_reminderGeneration;
    bool current() => !_disposed && generation == _reminderGeneration;
    final settings = _notificationSettings;
    final owner = _controller.scheduleWidgetOwner;
    final now = DateTime.now();
    try {
      if (owner == null) {
        // 退出登录或换账号时撤掉旧账号的全部提醒。
        await _notifications.replace(_courseNoticeGroup, const []);
        await _notifications.replace(_todoNoticeGroup, const []);
        return;
      }
      var courses = const <ScheduledNotification>[];
      if (settings.courseEnabled) {
        final list = await _controller.readUpcomingCourses(homeCampusTime(now));
        if (!current()) return;
        courses = _courseNotices(list, settings.courseLeads, now);
      }
      // 首页还没算出待办时保留上次排好的，免得启动时被清空。
      final home = _controller.homeState;
      final todos = !settings.todoEnabled
          ? const <ScheduledNotification>[]
          : home.projected
          ? _todoNotices(home.todos, settings.todoLeads, now)
          : null;
      final all = [...courses, ...?todos]
        ..sort((a, b) => a.at.compareTo(b.at));
      final keep = all.take(_maxScheduledNotices).map((n) => n.id).toSet();
      if (!current()) return;
      await _notifications.replace(
        _courseNoticeGroup,
        courses.where((n) => keep.contains(n.id)).toList(),
      );
      if (todos != null) {
        await _notifications.replace(
          _todoNoticeGroup,
          todos.where((n) => keep.contains(n.id)).toList(),
        );
      }
    } on Object {
      // 排提醒失败不影响其他功能，下次数据变化或整点刷新时再试。
    }
  }
}

List<ScheduledNotification> _courseNotices(
  List<UpcomingCourse> courses,
  List<int> leads,
  DateTime now,
) {
  final notices = <ScheduledNotification>[];
  for (final course in courses) {
    final start = _campusInstant(course.start);
    final place = course.place == null ? '' : ' · ${course.place}';
    for (final lead in leads) {
      final at = start.subtract(Duration(minutes: lead));
      if (!at.isAfter(now)) continue;
      final label = reminderLeadLabel(lead);
      notices.add(
        ScheduledNotification(
          id: _noticeId('course|${course.title}|${course.start}|$lead'),
          title: course.title,
          body: '$label后上课 · ${_clock(course.start)}$place',
          at: at,
        ),
      );
    }
  }
  return notices;
}

/// 签到在课程提醒里已经覆盖，这里只提醒有截止时间的待办。
List<ScheduledNotification> _todoNotices(
  List<HomeTodo> todos,
  List<int> leads,
  DateTime now,
) {
  final notices = <ScheduledNotification>[];
  for (final todo in todos) {
    final deadline = todo.deadline;
    if (deadline == null || todo.feature == FeatureId.signin) continue;
    final due = _campusInstant(deadline);
    final course = todo.subtitle.trim();
    final dueText = '${deadline.month}月${deadline.day}日 ${_clock(deadline)}';
    final extra = course.isEmpty ? '' : ' · $course';
    for (final lead in leads) {
      final at = due.subtract(Duration(minutes: lead));
      if (!at.isAfter(now)) continue;
      final label = reminderLeadLabel(lead);
      notices.add(
        ScheduledNotification(
          id: _noticeId('todo|${todo.id}|$deadline|$lead'),
          title: todo.title,
          body: '还有 $label截止 · $dueText$extra',
          at: at,
        ),
      );
    }
  }
  return notices;
}

/// 校园墙上时间（东八区）换成绝对时刻，手机时区不是东八区也不会错。
DateTime _campusInstant(DateTime wall) {
  final utc = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  return utc.subtract(const Duration(hours: 8));
}

String _clock(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

/// 同一节课同一档提醒的编号固定，重排时系统直接覆盖旧的那条。
int _noticeId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  // 落在 2^30 以上，小编号留给即时通知。
  return (hash & 0x3fffffff) | 0x40000000;
}
