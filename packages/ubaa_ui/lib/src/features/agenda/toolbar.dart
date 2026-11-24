part of 'view.dart';

extension _AgendaToolbar on AgendaViewState {
  /// 与外壳标题栏同高、同左边线和同字号，切换到日程时标题不跳动。
  Widget _buildToolbar({required bool wide}) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        UbaaTheme.pagePadding(width),
        MediaQuery.paddingOf(context).top,
        width >= 600 ? 12 : 4,
        0,
      ),
      child: SizedBox(
        height: width >= 600 ? 72 : 64,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '日程',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
              ),
            ),
            // 与外壳标题栏同一“更新中”状态，首次读取也在这里显示；
            // 下拉期间已有下拉指示器，不重复显示。
            UiSyncStatus(busy: loading && !pulling),
            IconButton(
              tooltip: '搜索日程',
              isSelected: searchVisible,
              onPressed: () => update(() {
                searchVisible = !searchVisible;
                if (searchVisible) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => searchFocus.requestFocus(),
                  );
                } else {
                  searchField.clear();
                  search = '';
                }
              }),
              icon: const Icon(Icons.search),
            ),
            // 宽屏左栏已常驻筛选，不再重复入口。
            if (!wide)
              IconButton(
                tooltip: '筛选日程',
                onPressed: showFilters,
                icon: Badge(
                  isLabelVisible: selectedFilterCount > 0,
                  label: Text('$selectedFilterCount'),
                  child: const Icon(Icons.tune),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: '更多日程操作',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    unawaited(export());
                  case 'refresh':
                    unawaited(load());
                  case 'school':
                    unawaited(refreshSchool());
                  case 'import':
                    importSchedule();
                  case 'data':
                    unawaited(dataSheet());
                }
              },
              itemBuilder: (_) => [
                _menuItem(
                  'data',
                  Icons.storage_outlined,
                  '数据与同步',
                  enabled: available,
                  key: const ValueKey('agenda-data-menu'),
                ),
                _menuItem(
                  'export',
                  Icons.ios_share,
                  '导出日历',
                  enabled: available && !busy,
                ),
                const PopupMenuDivider(),
                _menuItem(
                  'school',
                  Icons.cloud_download_outlined,
                  '刷新学校日程',
                  enabled: available,
                ),
                _menuItem(
                  'import',
                  Icons.calendar_month_outlined,
                  '刷新课表',
                  enabled: available,
                ),
                _menuItem('refresh', Icons.refresh, '重新加载', enabled: !loading),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    required bool enabled,
    Key? key,
  }) => PopupMenuItem(
    key: key,
    value: value,
    enabled: enabled,
    child: Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    ),
  );

  /// 月份（含周次）在左，回到今天和视图切换在右。手机上靠左右滑动翻页，
  /// 不放翻页箭头，月份有足够位置；宽屏多用鼠标，保留箭头。
  Widget _buildViewControls({required bool wide}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prev = mode == AgendaViewMode.month ? '上一月' : '上一周';
    final next = mode == AgendaViewMode.month ? '下一月' : '下一周';
    final week = customRange ? null : weekOf(focusDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  key: const ValueKey('agenda-range-label'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: range,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    // 大字号或年份较长时整体缩小，不再把月份省略成「…」或和箭头叠在一起。
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 月份和周次按文字基线对齐，周次小一号、颜色淡一些。
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                customRange
                                    ? rangeLabel
                                    : '${focusDate.year == agendaDay(now).year ? '' : '${focusDate.year}年'}${focusDate.month}月',
                                maxLines: 1,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (week != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '第$week周',
                                  key: const ValueKey('agenda-week-number'),
                                  maxLines: 1,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!_onToday)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '回到今天',
                color: colors.primary,
                onPressed: () => goDate(agendaDay(now)),
                icon: const Icon(Icons.today),
              ),
            if (wide) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: prev,
                onPressed: () => move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: next,
                onPressed: () => move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
            SegmentedButton<AgendaViewMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
                minimumSize: const WidgetStatePropertyAll(Size(40, 36)),
                tapTargetSize: MaterialTapTargetSize.padded,
                textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
              ),
              segments: const [
                ButtonSegment(
                  value: AgendaViewMode.list,
                  label: Text('列表'),
                  tooltip: '列表视图',
                ),
                ButtonSegment(
                  value: AgendaViewMode.week,
                  label: Text('周'),
                  tooltip: '周视图',
                ),
                ButtonSegment(
                  value: AgendaViewMode.month,
                  label: Text('月'),
                  tooltip: '月视图',
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => goMode(value.single),
            ),
          ],
        ),
      ],
    );
  }
}
