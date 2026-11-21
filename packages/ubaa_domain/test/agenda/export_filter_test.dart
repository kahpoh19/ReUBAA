import 'package:test/test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

// 按 Core 导出的格式拼一份日历：一节课、一条作业、一条自己添加的日程。
const _ics =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'BEGIN:VEVENT\r\n'
    'SUMMARY:编译技术\r\n'
    'X-UBAA-SOURCE;VALUE=TEXT:schedule\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VTODO\r\n'
    'SUMMARY:实验报告\r\n'
    'X-UBAA-SOURCE;VALUE=TEXT:spoc\r\n'
    'END:VTODO\r\n'
    'BEGIN:VEVENT\r\n'
    'SUMMARY:社团活动\r\n'
    'X-UBAA-SOURCE:local\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR\r\n';

void main() {
  test('全部导出时原样保留', () {
    final (ics, count) = filterAgendaIcs(_ics, AgendaExportContent.all);
    expect(ics, _ics);
    expect(count, 3);
  });

  test('只导出课程时只留课表条目，日历头尾不变', () {
    final (ics, count) = filterAgendaIcs(_ics, AgendaExportContent.courses);
    expect(count, 1);
    expect(ics, contains('编译技术'));
    expect(ics, isNot(contains('实验报告')));
    expect(ics, isNot(contains('社团活动')));
    expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
  });

  test('只导出待办时去掉课程，保留学校待办和自己的日程', () {
    final (ics, count) = filterAgendaIcs(_ics, AgendaExportContent.todos);
    expect(count, 2);
    expect(ics, isNot(contains('编译技术')));
    expect(ics, contains('实验报告'));
    expect(ics, contains('社团活动'));
  });
}
