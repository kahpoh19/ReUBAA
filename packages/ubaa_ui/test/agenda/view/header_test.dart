import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';
import 'package:ubaa_ui/src/features/agenda/view.dart';
import '../flow_test.dart' show opened;
import '../support.dart';

/// 合成学期：2026-09-07 周一是第 1 周，共 18 周。
FeatureResult _weeks() => FeatureResult.success(
  details: [
    for (var n = 1; n <= 18; n++)
      FeatureDetail(
        title: '第$n周',
        presentation: WeekPresentation(
          requestTerm: 'synthetic',
          responseTerm: 'synthetic',
          number: n,
          current: n == 9,
          startDate: _date(DateTime.utc(2026, 9, 7 + (n - 1) * 7)),
          endDate: _date(DateTime.utc(2026, 9, 13 + (n - 1) * 7)),
        ),
      ),
  ],
);

String _date(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

Widget _app(
  AgendaService service, {
  AgendaViewMode? mode,
  ValueChanged<AgendaViewMode>? onMode,
  TextScaler? textScaler,
  List<String>? weekReads,
}) => MaterialApp(
  theme: UbaaTheme.light(),
  localizationsDelegates: UbaaTheme.localizationsDelegates,
  supportedLocales: UbaaTheme.supportedLocales,
  locale: UbaaTheme.locale,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: textScaler ?? TextScaler.noScaling),
    child: child!,
  ),
  home: Scaffold(
    body: AgendaView(
      service: service,
      scopeKey: 1,
      route: ConnectionMode.direct,
      term: 'synthetic',
      now: DateTime(2026, 11, 5, 9),
      onOpenSchool: (_) {},
      loadWeeks: (term, force) async {
        weekReads?.add('$term $force');
        return _weeks();
      },
      initialMode: mode,
      onModeChanged: onMode,
    ),
  ),
);

void main() {
  testWidgets('手机顶栏不放翻页箭头，两位数月份、周次和回到今天互不遮挡', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = await opened(MemoryAgenda());
    final reads = <String>[];
    await tester.pumpWidget(
      _app(
        service,
        mode: AgendaViewMode.month,
        textScaler: const TextScaler.linear(1.3),
        weekReads: reads,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('下一月'), findsNothing);
    expect(find.byTooltip('上一月'), findsNothing);
    expect(find.text('第9周'), findsOneWidget);

    // 滑到 12 月：出现回到今天，月份、周次和下拉箭头仍完整排在它左边。
    await tester.fling(
      find.byKey(const ValueKey('agenda-swipe')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    final today = tester.getRect(find.byTooltip('回到今天'));
    final month = tester.getRect(find.text('12月'));
    final week = tester.getRect(find.text('第13周'));
    final arrow = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-range-label')),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
    );
    expect(month.width, greaterThan(20));
    expect(week.left, greaterThanOrEqualTo(month.right));
    expect(arrow.left, greaterThanOrEqualTo(week.right - .5));
    expect(arrow.right, lessThanOrEqualTo(today.left + .5));

    // 月历每行左边标出第几周：12 月从第 13 周排到第 17 周。
    for (final (row, number) in [(0, '13'), (4, '17')]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('agenda-month-week-$row')),
          matching: find.text(number),
        ),
        findsOneWidget,
      );
    }
    // 教学周只读一次本机优先的缓存，翻月不再重复读。
    expect(reads, ['synthetic false']);
  });

  testWidgets('学期外不显示周次', (tester) async {
    final service = await opened(MemoryAgenda());
    await tester.pumpWidget(_app(service, mode: AgendaViewMode.month));
    await tester.pumpAndSettle();
    final swipe = find.byKey(const ValueKey('agenda-swipe'));
    for (var i = 0; i < 3; i++) {
      await tester.fling(swipe, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
    // 2027 年 2 月已经过了第 18 周。
    expect(find.text('2027年2月'), findsOneWidget);
    expect(find.byKey(const ValueKey('agenda-week-number')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-month-week-0')), findsNothing);
  });

  testWidgets('打开时沿用保存的视图，手动切换后回调保存，迟到的保存值不覆盖', (tester) async {
    final service = await opened(MemoryAgenda());
    final saved = <AgendaViewMode>[];
    await tester.pumpWidget(
      _app(service, mode: AgendaViewMode.week, onMode: saved.add),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-week-content')), findsOneWidget);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(saved, [AgendaViewMode.month]);
    expect(find.byKey(const ValueKey('agenda-month-calendar')), findsOneWidget);

    // 保存值读得慢：还没手动切换时换过去，切过之后以用户为准。
    final late = await opened(MemoryAgenda());
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(late));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-week-content')), findsNothing);
    await tester.pumpWidget(_app(late, mode: AgendaViewMode.week));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-week-content')), findsOneWidget);
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(late, mode: AgendaViewMode.month));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-month-calendar')), findsNothing);
  });
}
