import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import '../shared/feedback.dart';

/// 设置页“通知”分组需要的状态与操作，由宿主装配。
///
/// [onChanged] 完成时宿主已经保存并重新排好提醒；失败时抛出，界面只提示。
final class UiNotificationControls {
  const UiNotificationControls({
    required this.settings,
    required this.onChanged,
    this.available = true,
    this.note,
  });
  final ReminderNotificationSettings settings;
  final Future<void> Function(ReminderNotificationSettings value) onChanged;

  /// 当前平台能不能发系统通知，不能时开关置灰。
  final bool available;

  /// 平台限制之类的补充说明。
  final String? note;
}

/// 课程提醒和待办提醒两个开关，打开后可以勾选提前多久提醒。
class NotificationSettings extends StatelessWidget {
  const NotificationSettings({super.key, required this.controls});
  final UiNotificationControls controls;

  ReminderNotificationSettings get _value => controls.settings;

  Future<void> _save(
    BuildContext context,
    ReminderNotificationSettings value,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await controls.onChanged(value);
    } on Object {
      if (messenger != null) {
        UbaaFeedback.showOn(
          messenger,
          '通知设置未能保存，请重试',
          kind: UbaaFeedbackKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final enabled = controls.available;
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('settings-course-notification'),
          secondary: const Icon(Icons.class_outlined),
          title: const Text('课程提醒'),
          subtitle: Text(
            !enabled
                ? '当前设备不支持系统通知'
                : _value.courseEnabled
                ? '上课前 ${_value.courseLeads.map(reminderLeadLabel).join('、')} 提醒'
                : '上课前发通知提醒',
          ),
          value: enabled && _value.courseEnabled,
          onChanged: enabled
              ? (on) => unawaited(
                  _save(context, _value.copyWith(courseEnabled: on)),
                )
              : null,
        ),
        if (enabled && _value.courseEnabled)
          _LeadPicker(
            key: const ValueKey('settings-course-leads'),
            presets: ReminderNotificationSettings.coursePresets,
            selected: _value.courseLeads,
            onChanged: (leads) =>
                unawaited(_save(context, _value.copyWith(courseLeads: leads))),
          ),
        const Divider(height: 1),
        SwitchListTile(
          key: const ValueKey('settings-todo-notification'),
          secondary: const Icon(Icons.task_alt_outlined),
          title: const Text('待办提醒'),
          subtitle: Text(
            !enabled
                ? '当前设备不支持系统通知'
                : _value.todoEnabled
                ? '截止前 ${_value.todoLeads.map(reminderLeadLabel).join('、')} 提醒'
                : '作业等待办截止前发通知提醒',
          ),
          value: enabled && _value.todoEnabled,
          onChanged: enabled
              ? (on) => unawaited(
                  _save(context, _value.copyWith(todoEnabled: on)),
                )
              : null,
        ),
        if (enabled && _value.todoEnabled)
          _LeadPicker(
            key: const ValueKey('settings-todo-leads'),
            presets: ReminderNotificationSettings.todoPresets,
            selected: _value.todoLeads,
            onChanged: (leads) =>
                unawaited(_save(context, _value.copyWith(todoLeads: leads))),
          ),
        if (controls.note case final note?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// 预设档位直接勾选；自定义的档位单独列出，可以删掉。至少保留一个。
class _LeadPicker extends StatelessWidget {
  const _LeadPicker({
    super.key,
    required this.presets,
    required this.selected,
    required this.onChanged,
  });
  final List<int> presets, selected;
  final ValueChanged<List<int>> onChanged;

  void _toggle(int lead, bool on) {
    if (!on && selected.length == 1) return;
    onChanged(
      on
          ? [...selected, lead]
          : selected.where((value) => value != lead).toList(),
    );
  }

  Future<void> _addCustom(BuildContext context) async {
    final lead = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomLeadDialog(),
    );
    if (lead != null && !selected.contains(lead)) {
      onChanged([...selected, lead]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = selected.where((lead) => !presets.contains(lead));
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final lead in presets)
              FilterChip(
                label: Text('前 ${reminderLeadLabel(lead)}'),
                selected: selected.contains(lead),
                onSelected: (on) => _toggle(lead, on),
              ),
            for (final lead in custom)
              InputChip(
                label: Text('前 ${reminderLeadLabel(lead)}'),
                selected: true,
                showCheckmark: false,
                onDeleted: selected.length == 1
                    ? null
                    : () => _toggle(lead, false),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('自定义'),
              onPressed: () => unawaited(_addCustom(context)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LeadUnit {
  minute('分钟', 1),
  hour('小时', 60),
  day('天', 1440);

  const _LeadUnit(this.label, this.minutes);
  final String label;
  final int minutes;
}

/// 输入一个数字再选单位，换算成分钟返回。
class _CustomLeadDialog extends StatefulWidget {
  const _CustomLeadDialog();
  @override
  State<_CustomLeadDialog> createState() => _CustomLeadDialogState();
}

class _CustomLeadDialogState extends State<_CustomLeadDialog> {
  final _text = TextEditingController();
  var _unit = _LeadUnit.minute;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final count = int.tryParse(_text.text.trim());
    final minutes = count == null ? null : count * _unit.minutes;
    if (minutes == null ||
        minutes <= 0 ||
        minutes > ReminderNotificationSettings.maxLead) {
      setState(() => _error = '请输入 1 分钟到 7 天之间的时间');
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('自定义提醒时间'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '提前多久',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        SegmentedButton<_LeadUnit>(
          showSelectedIcon: false,
          segments: [
            for (final unit in _LeadUnit.values)
              ButtonSegment(value: unit, label: Text(unit.label)),
          ],
          selected: {_unit},
          onSelectionChanged: (value) => setState(() => _unit = value.single),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('添加')),
    ],
  );
}
