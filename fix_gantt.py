import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. Kanban Drop Shadows
content = re.sub(
    r'color: Colors\.black\.withValues\(alpha: 0\.08\),\s*blurRadius: 8,\s*offset: const Offset\(0, 4\),',
    r'color: Colors.black.withValues(alpha: 0.15),\n                                    blurRadius: 10,\n                                    offset: const Offset(0, 5),',
    content
)
content = re.sub(
    r'color: Colors\.black\.withValues\(alpha: 0\.1\),\s*blurRadius: 6,\s*offset: const Offset\(0, 3\),',
    r'color: Colors.black.withValues(alpha: 0.25),\n              blurRadius: 10,\n              offset: const Offset(0, 4),',
    content
)

# 2. Modify _buildGanttChart for generic constraints and height limiting
gantt_chart_replacement = '''
  Widget _buildGanttChart(
    BuildContext context,
    List<Project> projects,
    List<ProjectTask> tasks,
    List<Subtask> subtasks,
  ) {
    if (projects.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    _ganttRowIndex = 0;

    bool isLandscapePhone = MediaQuery.of(context).orientation == Orientation.landscape && MediaQuery.of(context).size.height < 600;
    bool shouldBeFullscreen = _isFullscreenGantt || isLandscapePhone;

    return Theme(
      data: AppTheme.getTheme(isDark ? UIMode.light : UIMode.dark),
      child: Builder(
        builder: (context) {
          final invertedTheme = Theme.of(context);
          Widget ganttContent = Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFFBF8F1) : const Color(0xFF161816),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: invertedTheme.dividerColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildUniversalGantt(context, projects, tasks, subtasks, constraints, _ganttScale);
              },
            ),
          );

          if (!shouldBeFullscreen) {
            return SizedBox(
              height: 500, // Constrain height when not fullscreen
              child: ganttContent,
            );
          } else {
            return Expanded(child: ganttContent); // Fill space in fullscreen
          }
        },
      ),
    );
  }
'''
if "Widget _buildGanttChart(" in content:
    idx_start = content.find("Widget _buildGanttChart(")
    idx_end = content.find("Widget _buildUniversalGantt(")
    # Keep the // GANTT CHART CONTAINER comment intact if it exists above
    content = content[:idx_start] + gantt_chart_replacement + content[idx_end:]


# 3. Completely replace _buildUniversalGantt and _buildDayRow
universal_gantt_new = '''
  Widget _buildUniversalGantt(
    BuildContext context,
    List<Project> projects,
    List<ProjectTask> tasks,
    List<Subtask> subtasks,
    BoxConstraints constraints,
    GanttScale scale,
  ) {
    final theme = Theme.of(context);
    double availableWidth = constraints.maxWidth;
    if (availableWidth <= 0 || availableWidth.isInfinite || availableWidth.isNaN) {
      availableWidth = 1000;
    }
    const double labelWidth = 150;
    double timelineWidth = (availableWidth - labelWidth).clamp(400.0, double.infinity);

    int totalUnits = 1;
    double unitWidth = 0;
    DateTime startAnchor = _ganttAnchorDate;
    List<Widget> headerWidgets = [];
    double currentPos = -1;

    // Unit logic (same as before)
    if (scale == GanttScale.day) {
      int startHour = 7;
      int endHour = 19;
      for (var p in projects) {
        if (_spansDay(p.startDate, p.endDate, _ganttAnchorDate)) {
          for (var t in tasks.where((t) => t.projectId == p.id)) {
            if (_spansDay(t.startDate, t.endDate, _ganttAnchorDate)) {
              if (t.startDate.day == _ganttAnchorDate.day && t.startDate.hour < startHour) startHour = t.startDate.hour;
              if (t.endDate.day == _ganttAnchorDate.day && t.endDate.hour >= endHour) endHour = t.endDate.hour + 1;
            }
          }
        }
      }
      startHour = startHour.clamp(0, 24);
      endHour = endHour.clamp(startHour + 1, 24);
      totalUnits = endHour - startHour;
      unitWidth = (timelineWidth / totalUnits).clamp(40.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month, _ganttAnchorDate.day, startHour);

      if (_isToday(_ganttAnchorDate)) {
        final now = DateTime.now();
        currentPos = (now.hour - startHour + (now.minute / 60.0)) * unitWidth;
      }
      for (int i = 0; i < totalUnits; i++) {
        int h = startHour + i;
        bool isNow = DateTime.now().hour == h && _isToday(_ganttAnchorDate);
        String label = h == 0 ? '12am' : h < 12 ? '${h}am' : h == 12 ? '12pm' : '${h - 12}pm';
        headerWidgets.add(_buildHeaderCell(label, isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.week) {
      totalUnits = 7;
      unitWidth = (timelineWidth / totalUnits).clamp(60.0, double.infinity);
      int weekday = _ganttAnchorDate.weekday;
      startAnchor = _ganttAnchorDate.subtract(Duration(days: weekday - 1));
      startAnchor = DateTime(startAnchor.year, startAnchor.month, startAnchor.day);
      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(const Duration(days: 7)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }
      final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < 7; i++) {
        DateTime dayDate = startAnchor.add(Duration(days: i));
        bool isNow = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
        headerWidgets.add(_buildHeaderCell('${days[i]} ${dayDate.day}', isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.month) {
      int daysInMonth = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month + 1, 0).day;
      totalUnits = daysInMonth;
      unitWidth = (timelineWidth / totalUnits).clamp(30.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month, 1);
      final now = DateTime.now();
      if (now.year == _ganttAnchorDate.year && now.month == _ganttAnchorDate.month) {
        currentPos = (now.day - 1 + (now.hour / 24.0)) * unitWidth;
      }
      for (int i = 0; i < totalUnits; i++) {
        bool isNow = now.year == startAnchor.year && now.month == startAnchor.month && now.day == (i + 1);
        headerWidgets.add(_buildHeaderCell('${i + 1}', isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.year) {
      totalUnits = 12;
      unitWidth = (timelineWidth / totalUnits).clamp(60.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, 1, 1);
      final now = DateTime.now();
      int currentYear = DateTime.now().year;
      if (currentYear == _ganttAnchorDate.year) {
        int daysPassed = now.difference(startAnchor).inDays;
        int daysInYear = DateTime(currentYear, 12, 31).difference(startAnchor).inDays + 1;
        currentPos = (daysPassed / daysInYear) * (totalUnits * unitWidth);
      }
      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 0; i < 12; i++) {
        bool isNow = now.year == startAnchor.year && now.month == (i + 1);
        headerWidgets.add(_buildHeaderCell(months[i], isNow, unitWidth, theme));
      }
    }

    double maxTotalWidth = totalUnits * unitWidth;

    double _getFraction(DateTime d) {
      if (scale == GanttScale.day) {
        return d.difference(startAnchor).inMinutes / (totalUnits * 60);
      } else if (scale == GanttScale.week || scale == GanttScale.month) {
        return d.difference(startAnchor).inMinutes / (totalUnits * 24 * 60);
      } else if (scale == GanttScale.year) {
        DateTime endYear = DateTime(startAnchor.year + 1, 1, 1);
        return d.difference(startAnchor).inMinutes / endYear.difference(startAnchor).inMinutes;
      }
      return 0;
    }

    bool _isVisible(DateTime s, DateTime e) {
      return _getFraction(e) > 0 && _getFraction(s) < 1;
    }

    // Prepare lists of widgets for Left and Right columns safely
    List<Widget> leftColumnRows = [];
    List<Widget> rightColumnRows = [];

    for (var p in projects) {
      if (!_isVisible(p.startDate, p.endDate)) continue;
      bool collapsed = _collapsedGanttPhases.contains(p.id);

      // Add Phase row
      var pTuple = _buildDayRow(
        context, p.title, p.color, labelWidth, maxTotalWidth, () => _openPhaseEditor(p),
        isPhase: true, collapsed: collapsed, start: _getFraction(p.startDate), end: _getFraction(p.endDate),
        onToggle: () => setState(() { collapsed ? _collapsedGanttPhases.remove(p.id) : _collapsedGanttPhases.add(p.id); }),
      );
      leftColumnRows.add(pTuple[0]); rightColumnRows.add(pTuple[1]);

      if (!collapsed) {
        var pTasks = tasks.where((t) => t.projectId == p.id).toList();
        for (var t in pTasks) {
          if (!_isVisible(t.startDate, t.endDate)) continue;
          bool tCollapsed = _collapsedGanttTasks.contains(t.id);
          
          var tTuple = _buildDayRow(
            context, t.title, t.color, labelWidth, maxTotalWidth, () => _openTaskEditor(t),
            item: t, isTask: true, collapsed: tCollapsed, start: _getFraction(t.startDate), end: _getFraction(t.endDate),
            onToggle: () => setState(() { tCollapsed ? _collapsedGanttTasks.remove(t.id) : _collapsedGanttTasks.add(t.id); }),
          );
          leftColumnRows.add(tTuple[0]); rightColumnRows.add(tTuple[1]);

          if (!tCollapsed) {
            var subList = subtasks.where((s) => s.taskId == t.id).toList();
            for (var s in subList) {
              if (_isVisible(s.startDate, s.endDate)) {
                var sTuple = _buildDayRow(
                  context, s.title, s.color ?? t.color, labelWidth, maxTotalWidth, () => _openSubtaskEditor(s),
                  item: s, start: _getFraction(s.startDate), end: _getFraction(s.endDate),
                );
                leftColumnRows.add(sTuple[0]); rightColumnRows.add(sTuple[1]);
              }
            }
          }
        }
      }
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Frozen Column
            SizedBox(
              width: labelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 38), // Header artificial offset
                  ...leftColumnRows,
                ],
              ),
            ),
            // Right Horizontal Scrolling Body
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: maxTotalWidth,
                  child: Stack(
                    children: [
                      // Vertical Guide Lines
                      Row(
                        children: List.generate(totalUnits, (i) {
                          bool isBolder = false;
                          if (scale == GanttScale.month && (i % 7 == 0 || i == 0)) isBolder = true;
                          if (scale == GanttScale.year) isBolder = true;
                          
                          return Container(
                            width: unitWidth,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: theme.dividerColor.withValues(alpha: isBolder ? 0.2 : 0.05),
                                  width: isBolder ? 1.5 : 1.0
                                )
                              )
                            ),
                          );
                        }),
                      ),
                      // Gantt Rows and Headers
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: headerWidgets),
                          const SizedBox(height: 12),
                          ...rightColumnRows,
                        ],
                      ),
                      // Today Marker
                      if (currentPos >= 0 && currentPos <= maxTotalWidth)
                        Positioned(
                          left: currentPos,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: AppTheme.todayMarker(theme.brightness == Brightness.dark ? UIMode.dark : UIMode.light),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, bool isNow, double width, ThemeData theme) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
              color: isNow ? theme.primaryColor : theme.hintColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 2, color: isNow ? theme.primaryColor : theme.dividerColor.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  List<Widget> _buildDayRow(
    BuildContext context,
    String title,
    Color color,
    double labelWidth,
    double timelineWidth,
    VoidCallback onTap, {
    bool isPhase = false,
    bool isTask = false,
    bool collapsed = false,
    VoidCallback? onToggle,
    double start = 0,
    double end = 1,
    dynamic item,
  }) {
    final theme = Theme.of(context);
    final uiMode = theme.brightness == Brightness.dark ? UIMode.dark : UIMode.light;
    final rowWidth = timelineWidth;
    final rowIdx = _ganttRowIndex++;

    double rawStart = start;
    double rawEnd = end;
    bool extendsLeft = rawStart < 0;
    bool extendsRight = rawEnd > 1;
    bool startsAndEndsInside = !extendsLeft && !extendsRight;
    bool isSpanningEntirely = extendsLeft && extendsRight;
    bool isProminent = !isSpanningEntirely; // Starts or finishing in current view = prominent!

    double barHeight;
    if (isPhase) {
      barHeight = 10;
    } else if (isTask) {
      barHeight = isProminent ? 22 : 6;
    } else {
      barHeight = isProminent ? 16 : 4;
    }

    final left = (rawStart.clamp(0.0, 1.0) * rowWidth);
    final width = ((rawEnd.clamp(0.0, 1.0) - rawStart.clamp(0.0, 1.0)) * rowWidth).clamp(12.0, rowWidth - left);

    // Left Column Widget (Only has text if it's a phase)
    Widget leftWidget = Container(
      height: 36, // Standardize exact row height to perfectly align with right widget!!
      alignment: Alignment.centerLeft,
      color: Colors.transparent, // Background tracking across left column optional
      child: isPhase ? Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(collapsed ? Icons.arrow_right_rounded : Icons.arrow_drop_down_rounded, size: 20, color: theme.hintColor),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ) : const SizedBox.shrink(),
    );

    // Right Column Widget
    Widget rightWidget = Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isPhase ? color.withValues(alpha: 0.05) : Colors.transparent,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            if (isPhase)
              Container(height: 1, color: color.withValues(alpha: 0.3)),
            Positioned(
              left: left,
              width: width,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: isPhase ? Colors.transparent : color.withValues(alpha: isSpanningEntirely ? 0.3 : 1.0),
                  borderRadius: isPhase ? BorderRadius.circular(0) : BorderRadius.circular(barHeight / 2),
                  border: isPhase ? Border.symmetric(vertical: BorderSide(color: color, width: 3), horizontal: BorderSide(color: color, width: 1.5)) : null,
                  boxShadow: (isProminent && !isPhase) ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))] : null,
                ),
                child: (!isPhase && isProminent) ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: extendsLeft ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: GoogleFonts.outfit(
                        fontSize: isTask ? 10 : 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ) : null,
              ),
            ),
          ],
        ),
      ),
    );

    return [leftWidget, rightWidget];
  }
'''

idx_start_uni = content.find("Widget _buildUniversalGantt(")
idx_end_uni = content.find("List<Widget> _buildKanbanGroups(")

if idx_start_uni != -1 and idx_end_uni != -1:
    content = content[:idx_start_uni] + universal_gantt_new + content[idx_end_uni:]

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
