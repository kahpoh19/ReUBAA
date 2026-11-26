part of 'ubaa_app_host.dart';

/// iOS 不能常驻后台，课前用通知叫用户点开应用，单独一组。
const _signinNoticeGroup = 'signin';
const _maxSigninNotices = 4;

/// 每天早上这个时刻醒一次，读当天的签到列表把计划补全（东八区）。
const _signinMorningHour = 7, _signinMorningMinute = 20;

/// iClass 课程开始时间和课表对不上几分钟也算同一节。
const _signinMatchSlack = Duration(minutes: 15);

extension _UbaaAppHostAutoSignin on _UbaaAppHostState {
  UiAutoSigninControls? get _autoSigninControls => !_autoSignin.unlocked
      ? null
      : UiAutoSigninControls(
          enabled: _autoSignin.enabled,
          onChanged: _setAutoSigninEnabled,
          onHide: _hideAutoSignin,
          batteryUnrestricted: _keepAlive.isAvailable
              ? _batteryUnrestricted ?? false
              : null,
          onRequestUnrestricted: () => unawaited(_requestUnrestricted()),
          onOpenAutostart: () =>
              unawaited(_keepAlive.openAutostartSettings().catchError((_) {})),
          hideFromRecents: _autoSignin.hideFromRecents,
          onHideFromRecentsChanged: _keepAlive.isAvailable
              ? _setHideFromRecents
              : null,
          status: _signinStatus,
          note: _keepAlive.isAvailable
              ? '开启后通知栏会常驻一条“后台运行中”，开机自动启动；签到结果会发通知。'
              : Platform.isIOS
              ? 'iOS 不允许应用常驻后台：课前 4 分钟会发通知，点开应用并保持在前台即可自动签到。'
              : '应用保持打开时才会自动签到。',
        );

  /// 已解锁就不用再连点，关于页卡片不再响应。
  Future<void> Function()? get _unlockAutoSigninCallback =>
      _autoSigninLoaded && !_autoSignin.unlocked ? _unlockAutoSignin : null;

  Future<void> _loadAutoSignin() async {
    var value = const AutoSigninSettings();
    try {
      value = await _autoSigninStore.read();
    } on Object {
      // 读不到按默认隐藏处理。
    }
    if (_disposed) return;
    _refreshHost(() {
      _autoSignin = value;
      _autoSigninLoaded = true;
    });
    // 原生侧的开机自启和最近任务隐藏以这里为准，顺手同步一次。
    unawaited(_keepAlive.setEnabled(value.enabled).catchError((_) {}));
    unawaited(_syncHiddenFromRecents());
    if (value.enabled) unawaited(_refreshBattery());
    _syncAutoSignin();
  }

  Future<void> _saveAutoSignin(AutoSigninSettings value) async {
    final before = _autoSignin;
    _refreshHost(() => _autoSignin = value);
    try {
      await _autoSigninStore.write(value);
    } on Object {
      _refreshHost(() => _autoSignin = before);
      rethrow;
    }
  }

  Future<void> _unlockAutoSignin() =>
      _saveAutoSignin(_autoSignin.copyWith(unlocked: true));

  Future<void> _hideAutoSignin() async {
    if (_autoSignin.enabled) await _setAutoSigninEnabled(false);
    await _saveAutoSignin(const AutoSigninSettings());
  }

  Future<void> _setAutoSigninEnabled(bool enabled) async {
    // 签到结果靠通知告诉用户，没给权限也照样签。
    if (enabled) await _notifications.requestPermission();
    await _saveAutoSignin(_autoSignin.copyWith(enabled: enabled));
    try {
      await _keepAlive.setEnabled(enabled);
    } on Object {
      // 原生服务起不来时前台仍然可以签。
    }
    await _syncHiddenFromRecents();
    if (enabled) {
      await _refreshBattery();
      _signinStamp = null;
      _syncAutoSignin();
    } else {
      _stopAutoSignin();
    }
  }

  Future<void> _setHideFromRecents(bool hidden) async {
    await _saveAutoSignin(_autoSignin.copyWith(hideFromRecents: hidden));
    await _syncHiddenFromRecents();
  }

  /// 功能关着时总是不隐藏；系统不支持时只是不隐藏，不影响其他设置。
  Future<void> _syncHiddenFromRecents() async {
    try {
      await _keepAlive.setHiddenFromRecents(_autoSignin.hidesFromRecents);
    } on Object {
      // 留给下次打开应用时再同步。
    }
  }

  Future<void> _refreshBattery() async {
    if (!_keepAlive.isAvailable) return;
    final value = await _keepAlive.batteryUnrestricted();
    if (!_disposed) _refreshHost(() => _batteryUnrestricted = value);
  }

  Future<void> _requestUnrestricted() async {
    try {
      await _keepAlive.requestUnrestricted();
    } on Object {
      // 系统设置页打不开就算了，回到前台时会重新读取状态。
    }
  }

  void _stopAutoSignin() {
    _signinWake?.cancel();
    _signinWake = null;
    _signinPlanDelay?.cancel();
    _stopSigninLoop();
    _signinStarts = const [];
    unawaited(_keepAlive.scheduleWakes(const []).catchError((_) {}));
    unawaited(
      _notifications.replace(_signinNoticeGroup, const []).catchError((_) {}),
    );
  }

  /// 课表缓存或签到列表变了就重新算今天往后的签到窗口。
  void _syncAutoSignin() {
    if (_disposed ||
        _readyController == null ||
        !_autoSigninLoaded ||
        !_autoSignin.enabled)
      return;
    final stamp = (
      _controller.scheduleWidgetOwner,
      _controller.scheduleWidgetRevision,
      _controller.agendaProjectionEpoch,
      _controller.snapshots[FeatureId.signin]?.updatedAt,
      homeDateKey(homeCampusTime(DateTime.now())),
    );
    if (stamp == _signinStamp) return;
    _signinStamp = stamp;
    _signinPlanDelay?.cancel();
    _signinPlanDelay = Timer(
      const Duration(seconds: 2),
      () => unawaited(_planAutoSignin()),
    );
  }

  Future<void> _planAutoSignin() async {
    if (_disposed || !_autoSignin.enabled) return;
    final now = DateTime.now();
    final today = homeCampusTime(now);
    final names = <DateTime, String>{};
    if (_controller.scheduleWidgetOwner != null) {
      try {
        for (final course in await _controller.readUpcomingCourses(today)) {
          names[_campusInstant(course.start)] = course.title;
        }
      } on Object {
        // 课表缓存读不到时只靠签到列表。
      }
    }
    for (final (begin, title) in _signinClasses(today)) {
      // 课表里已经有这节课就不重复加窗口。
      final known = names.keys.any(
        (s) => s.difference(begin).abs() <= _signinMatchSlack,
      );
      if (!known) names[begin] = title;
    }
    if (_disposed || !_autoSignin.enabled) return;
    final starts = [
      for (final s in names.keys)
        if (s.add(AutoSigninSettings.grace).isAfter(now)) s,
    ]..sort();
    _signinStarts = starts;
    _signinNames
      ..clear()
      ..addAll({for (final s in starts) s: names[s]!});
    final wakes = [
      for (final s in starts) s.subtract(AutoSigninSettings.lead),
      _nextSigninMorning(now),
    ].where((t) => t.isAfter(now)).toList()..sort();
    try {
      await _keepAlive.scheduleWakes(wakes.take(48).toList());
    } on Object {
      // 闹钟排不上时，应用活着就靠下面的计时器。
    }
    if (!_keepAlive.isAvailable && Platform.isIOS) {
      unawaited(
        _notifications
            .replace(_signinNoticeGroup, [
              for (final s in starts.take(_maxSigninNotices))
                if (s.subtract(AutoSigninSettings.lead) case final at
                    when at.isAfter(now))
                  ScheduledNotification(
                    id: _noticeId('signin|$s'),
                    title: '${_signinNames[s]} 快上课了',
                    body: '点开 ReUBAA 自动签到，签好前请保持应用在前台',
                    at: at,
                  ),
            ])
            .catchError((_) {}),
      );
    }
    _armSigninWake();
  }

  /// 今天签到列表里每节课的开始时刻；列表不是今天读的就不用，免得把昨天的课算到今天。
  List<(DateTime, String)> _signinClasses(DateTime today) {
    final snapshot = _controller.snapshots[FeatureId.signin];
    final updated = snapshot?.updatedAt;
    if (snapshot == null ||
        updated == null ||
        homeDateKey(homeCampusTime(updated)) != homeDateKey(today))
      return const [];
    return [
      for (final detail in snapshot.details)
        if (detail.presentation case final SigninPresentation p)
          if (_signinBegin(p.classBeginTime, today) case final begin?)
            (begin, detail.title),
    ];
  }

  bool _signinWindowOpen(DateTime start, DateTime now) =>
      !_signinSettled.contains(start) &&
      !now.isBefore(start.subtract(AutoSigninSettings.lead)) &&
      now.isBefore(start.add(AutoSigninSettings.grace));

  /// 在窗口里就开始轮询；不在就定个计时器等下一个窗口或明早的检查。
  void _armSigninWake() {
    _signinWake?.cancel();
    _signinWake = null;
    if (_disposed || !_autoSigninLoaded || !_autoSignin.enabled) return;
    final now = DateTime.now();
    if (_signinStarts.any((s) => _signinWindowOpen(s, now))) {
      _startSigninLoop();
      return;
    }
    final next = [
      for (final s in _signinStarts)
        if (!_signinSettled.contains(s)) s.subtract(AutoSigninSettings.lead),
      _nextSigninMorning(now),
    ].where((t) => t.isAfter(now)).reduce((a, b) => a.isBefore(b) ? a : b);
    _signinWake = Timer(next.difference(now), _onSigninWake);
  }

  /// 闹钟或计时器把应用叫醒。不在窗口里就是早上的例行检查。
  void _onSigninWake() {
    if (_disposed || !_autoSigninLoaded || !_autoSignin.enabled) return;
    _armSigninWake();
    if (_signinLoop == null) unawaited(_refreshSigninPlan());
  }

  Future<void> _refreshSigninPlan() async {
    if (_signinRefreshing || _readyController == null) return;
    _signinRefreshing = true;
    _setSigninAwake(true);
    try {
      await _controller.resumeSession().timeout(const Duration(minutes: 1));
      if (_controller.phase == AppPhase.home) {
        await _controller
            .refreshFeatureQuery(FeatureId.signin, const FeatureQuery())
            .timeout(const Duration(minutes: 1));
      }
    } on Object {
      // 网络不好就等下一次醒来。
    } finally {
      _signinRefreshing = false;
      if (_signinLoop == null) {
        _setSigninAwake(false);
        unawaited(_keepAlive.release().catchError((_) {}));
      }
    }
    _signinStamp = null;
    _syncAutoSignin();
  }

  void _startSigninLoop() {
    if (_signinLoop != null) return;
    _setSigninAwake(true);
    unawaited(_controller.resumeSession().catchError((_) {}));
    _signinLoop = Timer.periodic(
      AutoSigninSettings.interval,
      (_) => unawaited(_signinTick()),
    );
    unawaited(_signinTick());
  }

  void _stopSigninLoop() {
    final running = _signinLoop != null;
    _signinLoop?.cancel();
    _signinLoop = null;
    if (!running) return;
    _setSigninAwake(false);
    unawaited(_keepAlive.release().catchError((_) {}));
  }

  /// 签到窗口里让控制器按前台处理，后台也能恢复会话和读写，结束后还原。
  void _setSigninAwake(bool awake) {
    if (_signinAwake == awake || _readyController == null) return;
    _signinAwake = awake;
    _controller.setAppForeground(awake || !_wasBackgrounded);
  }

  /// 每 30 秒一轮：先只读刷新签到列表，已签就收工；没签且能签才提交一次。
  /// 提交结果不明时不重发，下一轮读到的状态说了算。
  Future<void> _signinTick() async {
    if (_signinBusy || _disposed) return;
    _signinBusy = true;
    try {
      final now = DateTime.now();
      _reportMissedSignin(now);
      final open = _signinStarts
          .where((s) => _signinWindowOpen(s, now))
          .toList();
      if (open.isEmpty) {
        _stopSigninLoop();
        _armSigninWake();
        return;
      }
      if (_controller.phase != AppPhase.home) return;
      if (_controller.sessionRecoveryStatus ==
          SessionRecoveryStatus.needsLogin) {
        _notifySigninOnce(
          'login|${homeDateKey(homeCampusTime(now))}',
          '自动签到暂停',
          '登录已失效，请打开 ReUBAA 重新登录',
        );
        return;
      }
      final write = _controller.writeCoordinator.state;
      // 用户正在做别的写操作，这一轮让开。
      if (write.intent != null || write.isSubmitting) return;
      await _controller.refreshFeatureQuery(
        FeatureId.signin,
        const FeatureQuery(),
      );
      if (_disposed) return;
      final today = homeCampusTime(DateTime.now());
      for (final detail
          in _controller.snapshots[FeatureId.signin]?.details ??
              const <FeatureDetail>[]) {
        final p = detail.presentation;
        if (p is! SigninPresentation) continue;
        final begin = _signinBegin(p.classBeginTime, today);
        if (begin == null) continue;
        final starts = open
            .where((s) => s.difference(begin).abs() <= _signinMatchSlack)
            .toList();
        if (starts.isEmpty) continue;
        _signinSeen.addAll(starts);
        if (p.signStatus == 1) {
          // 已经签上（可能是用户自己签的），这节课不用再管。
          _signinSettled.addAll(starts);
          continue;
        }
        final action = detail.actions
            .whereType<SigninPerformAction>()
            .firstOrNull;
        if (action == null || action.eligibility != ActionEligibility.allowed)
          continue;
        if (await _performSignin(action)) {
          _signinSettled.addAll(starts);
          _signinResult(begin, detail.title, true);
        }
      }
      // 窗口里的课都签上了就提前收工。
      if (!_signinStarts.any((s) => _signinWindowOpen(s, DateTime.now()))) {
        _stopSigninLoop();
        _armSigninWake();
      }
    } on Object {
      // 读写失败（断网、会话恢复中）都等下一轮。
    } finally {
      _signinBusy = false;
    }
  }

  Future<bool> _performSignin(SigninPerformAction action) async {
    WriteIntent? intent;
    try {
      intent = await _controller.prepareSigninWrite(action);
      final result = await _controller.commitWrite(intent.intentId);
      if (result.success && !result.outcomeUnknown) {
        unawaited(
          _controller
              .refreshAfterWrite(WriteOperation.signinPerform)
              .catchError((_) {}),
        );
        return true;
      }
      return false;
    } on Object {
      // 提交前就失败的意图要释放，已提交的再释放也没关系。
      if (intent != null) {
        unawaited(
          _controller.discardWriteIntent(intent.intentId).catchError((_) {}),
        );
      }
      return false;
    }
  }

  /// 窗口过了还没签上的课发一条通知，每节只发一次。
  /// 签到列表里根本没有的课（不用 iClass 签到）不提醒。
  void _reportMissedSignin(DateTime now) {
    for (final start in _signinSeen) {
      if (_signinSettled.contains(start) ||
          now.isBefore(start.add(AutoSigninSettings.grace)))
        continue;
      _signinResult(start, _signinNames[start] ?? '课程', false);
    }
  }

  void _signinResult(DateTime begin, String title, bool success) {
    final key = 'result|$begin';
    if (!_signinReported.add(key)) return;
    final clock = _clock(homeCampusTime(begin));
    _refreshHost(
      () => _signinStatus = success
          ? '$clock $title：已自动签到'
          : '$clock $title：自动签到未成功',
    );
    unawaited(
      _notifications
          .show(
            _noticeId(key),
            success ? '已自动签到' : '自动签到未成功',
            success ? '$title（$clock 上课）' : '$title（$clock 上课），请尽快手动签到',
          )
          .catchError((_) {}),
    );
  }

  void _notifySigninOnce(String key, String title, String body) {
    if (!_signinReported.add(key)) return;
    unawaited(
      _notifications.show(_noticeId(key), title, body).catchError((_) {}),
    );
  }
}

/// 签到列表的开始时间，有日期就用日期，只有时刻就放在今天。
DateTime? _signinBegin(String raw, DateTime today) {
  final text = raw.trim();
  final full = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})',
  ).firstMatch(text);
  if (full != null) {
    return _campusInstant(
      DateTime(
        int.parse(full[1]!),
        int.parse(full[2]!),
        int.parse(full[3]!),
        int.parse(full[4]!),
        int.parse(full[5]!),
      ),
    );
  }
  final clock = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (clock == null) return null;
  return _campusInstant(
    DateTime(
      today.year,
      today.month,
      today.day,
      int.parse(clock[1]!),
      int.parse(clock[2]!),
    ),
  );
}

/// 下一个早上 7:20（东八区）。
DateTime _nextSigninMorning(DateTime now) {
  final campus = homeCampusTime(now);
  var morning = DateTime(
    campus.year,
    campus.month,
    campus.day,
    _signinMorningHour,
    _signinMorningMinute,
  );
  if (!morning.isAfter(campus)) {
    morning = DateTime(
      campus.year,
      campus.month,
      campus.day + 1,
      _signinMorningHour,
      _signinMorningMinute,
    );
  }
  return _campusInstant(morning);
}
