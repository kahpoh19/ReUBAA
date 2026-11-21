import 'package:ubaa_domain/ubaa_domain.dart';
import '../contracts/backend.dart';
import '../contracts/offline.dart';

/// 课程提醒、课前签到用的一节课。时间都是校园墙上时间（东八区）。
final class UpcomingCourse {
  const UpcomingCourse({
    required this.title,
    required this.start,
    this.end,
    this.place,
  });
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? place;
}

/// 从本机已加密保存的完整周课表里取 [from] 起 [days] 天的课，不发学校请求。
///
/// 只能拿到看过或保存过的周，首页会顺手缓存本周，所以至少有本周的课。
Future<List<UpcomingCourse>> readUpcomingCourses({
  required OfflineQueryBackend backend,
  required String owner,
  required RoutePolicy policy,
  required bool Function() isCurrent,
  required DateTime from,
  int days = 7,
}) async {
  void check() {
    if (!isCurrent()) {
      throw const BackendException(UbaaErrorCode.operationConflict);
    }
  }

  Future<CachedFeatureProjection?> read(FeatureQuery query) async {
    check();
    final result = await backend.readCachedQuery(
      FeatureId.schedule,
      query,
      policy,
    );
    check();
    final value = result.projection;
    if (value == null ||
        !value.complete ||
        value.accountId != owner ||
        value.feature != FeatureId.schedule ||
        !value.readContext.hasSameQuery(query))
      return null;
    return value;
  }

  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(from.year, from.month, from.day + days - 1);
  final courses = <UpcomingCourse>[];
  final seen = <String>{};
  final terms = await read(
    const FeatureQuery(view: FeatureQueryView.scheduleTerms),
  );
  for (final item in terms?.details ?? const <FeatureDetail>[]) {
    final term = item.presentation;
    if (term is! TermPresentation || term.code.isEmpty) continue;
    final weeks = await read(
      FeatureQuery(view: FeatureQueryView.scheduleWeeks, term: term.code),
    );
    for (final detail in weeks?.details ?? const <FeatureDetail>[]) {
      final week = detail.presentation;
      if (week is! WeekPresentation ||
          week.number < 1 ||
          week.requestTerm != week.responseTerm)
        continue;
      final start = homeParseDate(week.startDate);
      final end = homeParseDate(week.endDate);
      // 只看和这几天有交集的周，别的周不读。
      if (start == null ||
          end == null ||
          end.isBefore(first) ||
          start.isAfter(last))
        continue;
      final schedule = await read(
        FeatureQuery(
          view: FeatureQueryView.scheduleWeek,
          term: term.code,
          week: week.number,
        ),
      );
      if (schedule == null) continue;
      final list = schedule.details
          .map((d) => d.presentation)
          .whereType<ScheduleCoursePresentation>()
          .toList();
      final overview = schedule.overview;
      final sections = {
        for (final t in scheduleSectionTimes(
          courses: list,
          explicit: overview is ScheduleWeekOverview
              ? overview.sectionTimes
              : const [],
          code: overview is ScheduleWeekOverview ? overview.code : null,
        ))
          t.section: t,
      };
      for (final course in schedule.details) {
        final p = course.presentation;
        if (p is! ScheduleCoursePresentation ||
            p.dayOfWeek == null ||
            p.dayOfWeek! < 1 ||
            p.dayOfWeek! > 7)
          continue;
        // 周一加上星期几得到当天，周课表的起始日都是周一。
        final day = DateTime(
          start.year,
          start.month,
          start.day + p.dayOfWeek! - 1,
        );
        if (day.isBefore(first) || day.isAfter(last)) continue;
        final begin = _at(day, p.beginTime ?? sections[p.beginSection]?.start);
        if (begin == null) continue;
        final finish = _at(day, p.endTime ?? sections[p.endSection]?.end);
        if (!seen.add('${course.title}|${begin.toIso8601String()}')) continue;
        courses.add(
          UpcomingCourse(
            title: course.title,
            start: begin,
            end: finish,
            place: p.place?.trim().isEmpty == true ? null : p.place?.trim(),
          ),
        );
      }
    }
  }
  check();
  courses.sort((a, b) => a.start.compareTo(b.start));
  return courses;
}

/// 把 08:00 这种时刻放到 [day] 上，格式不对返回 null。
DateTime? _at(DateTime day, String? clock) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clock?.trim() ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return DateTime(day.year, day.month, day.day, hour, minute);
}
