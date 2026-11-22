import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../../theme.dart';
import 'calendar_values.dart';
import 'format.dart';

/// 日期圆的底色和数字颜色。Material：今天实心、选中浅色；Miuix 跟 HyperOS 日历一样，
/// 选中实心、今天只把数字染成强调色。[ring] 表示今天又被选中时要不要加一圈浅色边。
({Color circle, Color number, bool ring}) agendaDayColors(
  BuildContext context, {
  required bool selected,
  required bool today,
  required Color plain,
}) {
  final colors = Theme.of(context).colorScheme;
  if (UbaaTheme.miuix(context)) {
    return (
      circle: selected ? colors.primary : Colors.transparent,
      number: selected
          ? colors.onPrimary
          : today
          ? colors.primary
          : plain,
      ring: false,
    );
  }
  return (
    circle: today
        ? colors.primary
        : selected
        ? colors.primaryContainer
        : Colors.transparent,
    number: today
        ? colors.onPrimary
        : selected
        ? colors.onPrimaryContainer
        : plain,
    ring: today && selected,
  );
}

/// 日期下方的圆点：课程只占一个中性色点，其余事项按来源色去重，最多三个。
///
/// 几乎每天都有课，逐项画点看不出差别；这样有截止、考试或自建事项的日子才显眼。
List<Color> agendaDayDots(
  Iterable<AgendaEntry> dayEntries,
  Color Function(AgendaEntry)? colorOf,
  ColorScheme colors,
) {
  final dots = <Color>[];
  var course = false;
  for (final e in dayEntries) {
    if (e.school?.navigation.feature == AgendaFeature.schedule) {
      course = true;
      continue;
    }
    final color = colorOf?.call(e) ?? colors.primary;
    if (!dots.contains(color)) dots.add(color);
  }
  return [
    if (course) colors.onSurfaceVariant.withValues(alpha: .4),
    ...dots,
  ].take(3).toList();
}

class AgendaMonthCalendar extends StatelessWidget {
  const AgendaMonthCalendar({
    super.key,
    required this.date,
    required this.entries,
    required this.onSelected,
    this.today,
    this.colorOf,
  });
  final DateTime date;
  final DateTime? today;
  final List<AgendaEntry> entries;
  final ValueChanged<DateTime> onSelected;
  final Color Function(AgendaEntry)? colorOf;
  @override
  Widget build(BuildContext context) {
    final first = agendaWeekStart(DateTime.utc(date.year, date.month));
    final days =
        7 *
        ((DateTime.utc(date.year, date.month).difference(first).inDays +
                DateUtils.getDaysInMonth(date.year, date.month) +
                6) ~/
            7);
    final byDay = agendaEntriesByDay(entries, first, days);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GridView.builder(
            key: const ValueKey('agenda-month-calendar'),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: math.max(48, 44 * scale),
            ),
            itemCount: days,
            itemBuilder: (context, index) {
              final day = first.add(Duration(days: index));
              final dayEntries = byDay[day] ?? const <AgendaEntry>[];
              final count = dayEntries.length;
              final selected = day == agendaDay(date);
              final isToday = today != null && agendaDay(today!) == day;
              final colors = Theme.of(context).colorScheme;
              final look = agendaDayColors(
                context,
                selected: selected,
                today: isToday,
                plain: day.month == date.month
                    ? colors.onSurface
                    : colors.outlineVariant,
              );
              return Semantics(
                label: '${agendaDate(day)}，$count项',
                selected: selected,
                button: true,
                child: InkWell(
                  key: ValueKey('agenda-day-${agendaDate(day)}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 与列表、周视图一致：今天是实心圆，选中的其他日期是浅色圆。
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: look.circle,
                            border: look.ring
                                ? Border.all(
                                    color: colors.primaryContainer,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${day.day}',
                              maxLines: 1,
                              style: TextStyle(
                                color: look.number,
                                fontWeight: selected || isToday
                                    ? FontWeight.w500
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final dot in agendaDayDots(
                                dayEntries,
                                colorOf,
                                colors,
                              ))
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dot,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AgendaDateStrip extends StatelessWidget {
  const AgendaDateStrip({
    super.key,
    required this.date,
    required this.entries,
    required this.onSelected,
    this.today,
    this.onSwipe,
    this.colorOf,
  });
  final DateTime date;
  final DateTime? today;
  final List<AgendaEntry> entries;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int>? onSwipe;
  final Color Function(AgendaEntry)? colorOf;
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final monday = agendaWeekStart(date);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: onSwipe == null
          ? null
          : (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() > 200) onSwipe!(v < 0 ? 1 : -1);
            },
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = monday.add(Duration(days: i));
                  final selected = agendaDay(date) == day;
                  final isToday = today != null && agendaDay(today!) == day;
                  final dayEntries = entries
                      .where((e) => agendaOnDay(e, day))
                      .toList();
                  final weekend = i >= 5;
                  // 日期圆随字号放大，但不超过一周七格的宽度。
                  final circleSize = MediaQuery.textScalerOf(
                    context,
                  ).scale(36).clamp(36.0, 50.0);
                  final look = agendaDayColors(
                    context,
                    selected: selected,
                    today: isToday,
                    plain: weekend ? colors.onSurfaceVariant : colors.onSurface,
                  );
                  final circle = look.circle, number = look.number;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label:
                        '周${_weekdays[i]} ${day.month}月${day.day}日${dayEntries.isEmpty ? '' : '，有事项'}',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(day),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _weekdays[i],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isToday
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: isToday
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: circleSize,
                              height: circleSize,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: circle,
                                shape: BoxShape.circle,
                                border: look.ring
                                    ? Border.all(
                                        color: colors.primaryContainer,
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${day.day}',
                                  maxLines: 1,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: number,
                                    fontWeight: isToday || selected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final dot in agendaDayDots(
                                    dayEntries,
                                    colorOf,
                                    colors,
                                  ))
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: dot,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
