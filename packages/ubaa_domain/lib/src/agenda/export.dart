import 'school.dart';
import 'models.dart';

/// Core 展开的日期范围快照，不包含完整重复系列。
final class AgendaExportResult {
  const AgendaExportResult({
    required this.ics,
    required this.exportedCount,
    required this.skippedUnknownTimeCount,
  });
  final String ics;
  final int exportedCount;
  final int skippedUnknownTimeCount;
}

abstract interface class AgendaExportBackend {
  Future<AgendaExportResult> exportIcs(
    AgendaQuery query,
    bool includeCompleted,
  );
}

abstract interface class AgendaDraftBackend {
  Future<String?> editDraft(
    String id,
    AgendaEditScope scope,
    AgendaTime? at,
    AgendaDraft draft,
    AgendaTime now,
  );
}

/// 导出日历时选导出哪些：课程是学校课表，待办是作业、考试等学校事项和自己添加的日程。
enum AgendaExportContent {
  all('全部'),
  courses('仅课程'),
  todos('仅待办');

  const AgendaExportContent(this.label);
  final String label;
}

/// 按 [content] 过滤 Core 导出的 ICS，返回过滤后的文本和保留的条数。
///
/// 每个 VEVENT/VTODO 都带 X-UBAA-SOURCE，课表是 schedule，其余（学校待办、
/// 本地日程 local）算待办。日历头尾原样保留。
(String, int) filterAgendaIcs(String ics, AgendaExportContent content) {
  final lines = ics.split('\r\n');
  final out = <String>[];
  var block = <String>[];
  var inside = false, kept = 0;
  for (final line in lines) {
    if (!inside && (line == 'BEGIN:VEVENT' || line == 'BEGIN:VTODO')) {
      inside = true;
      block = [line];
      continue;
    }
    if (!inside) {
      out.add(line);
      continue;
    }
    block.add(line);
    if (line != 'END:VEVENT' && line != 'END:VTODO') continue;
    inside = false;
    final source = block
        .where((l) => l.startsWith('X-UBAA-SOURCE'))
        .map((l) => l.substring(l.indexOf(':') + 1))
        .firstOrNull;
    final course = source == 'schedule';
    final keep = switch (content) {
      AgendaExportContent.all => true,
      AgendaExportContent.courses => course,
      AgendaExportContent.todos => !course,
    };
    if (keep) {
      out.addAll(block);
      kept++;
    }
  }
  return (out.join('\r\n'), kept);
}
