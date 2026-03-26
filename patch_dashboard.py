import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Add _getUrgency (after _getFraction)
code = re.sub(
    r'(double _getFraction.*?}\n)',
    r'\1\n  int _getUrgency(DateTime endDate, TaskStatus status) {\n    if (status == TaskStatus.done) return 0;\n    final now = DateTime.now();\n    if (endDate.isBefore(now)) return 2;\n    if (endDate.isAfter(now) && endDate.difference(now).inHours <= 72) return 1;\n    return 0;\n  }\n',
    code,
    count=1,
    flags=re.DOTALL
)

# 2. Add 'dynamic item' and logic to _buildDayRow
code = re.sub(
    r'(double start = 0,\n    double end = 1,\n  }) {(\n.*?rowIdx = _ganttRowIndex\+\+;)',
    r'\1    dynamic item,\n  } {\2\n\n    int urgency = 0;\n    if (item is ProjectTask) urgency = _getUrgency(item.endDate, item.status);\n    if (item is Subtask) urgency = _getUrgency(item.endDate, item.status);',
    code,
    count=1,
    flags=re.DOTALL
)

# Box shadow fix for DayRow
box_shadow_replace = r'''
                              border: urgency > 0 ? Border.all(
                                color: urgency == 2 ? Colors.red : Colors.amber,
                                width: 2.0,
                              ) : null,
\1
                              boxShadow: urgency == 2 ? [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ] : (startsAndEndsInside ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ] : []),
'''
code = re.sub(
    r'(                              borderRadius: BorderRadius\.only\(.*?,\n                              \),\n)                              boxShadow: \[\n.*?\n                              \],',
    box_shadow_replace.strip('\n'),
    code,
    count=1,
    flags=re.DOTALL
)

# 3. Add 'dynamic item' and logic to _buildGanttRow
code = re.sub(
    r'(bool collapsed = false, VoidCallback\? onToggle}) {(\n.*?rowIdx = _ganttRowIndex\+\+;)',
    r'\1, dynamic item} {\2\n\n    int urgency = 0;\n    if (item is ProjectTask) urgency = _getUrgency(item.endDate, item.status);\n    if (item is Subtask) urgency = _getUrgency(item.endDate, item.status);',
    code,
    count=1,
    flags=re.DOTALL
)

# Box shadow fix for GanttRow
box_shadow_replace_gantt = r'''
                          border: urgency > 0 ? Border.all(
                            color: urgency == 2 ? Colors.red : Colors.amber,
                            width: 2.0,
                          ) : null,
\1
                          boxShadow: urgency == 2 ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.8),
                              blurRadius: 16,
                              spreadRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ] : (startsAndEndsInside ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ] : []),
'''
code = re.sub(
    r'(                          borderRadius: BorderRadius\.only\(.*?,\n                          \),\n)                          boxShadow: \[\n.*?\n                          \],',
    box_shadow_replace_gantt.strip('\n'),
    code,
    count=1,
    flags=re.DOTALL
)

# 4. Inject item: t for task calls and item: s for subtask calls across all Day/Week/Month/Year methods
code = re.sub(r'(\(\) => _openTaskEditor\(t\),)([\s\n]*)height: (\d+),', r'\1\2item: t,\2height: \3,', code)
code = re.sub(r'(\(\) => _openSubtaskEditor\(s\),)([\s\n]*)height: (\d+)[,]?', r'\1\2item: s,\2height: \3,', code)


# 5. Fix Kanban Task Tiles glow removal and urgency border
kanban_task_replace = r'''
                  int taskUrgency = _getUrgency(t.endDate, t.status);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: taskUrgency == 2 ? Colors.red : (taskUrgency == 1 ? Colors.amber : (allDone ? theme.dividerColor.withValues(alpha: 0.2) : t.color.withValues(alpha: 0.3))),
                        width: taskUrgency > 0 ? 2.0 : 1.0,
                      ),
                      color: allDone ? theme.scaffoldBackgroundColor : t.color.withValues(alpha: 0.05),
                      boxShadow: taskUrgency == 2 ? [
                        BoxShadow(color: Colors.red.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 4, offset: const Offset(0, 4))
                      ] : [],
                    ),
'''
code = re.sub(
    r'                  return AnimatedContainer\(\n.*?boxShadow: .*?\n                    \),',
    kanban_task_replace.strip('\n'),
    code,
    count=1,
    flags=re.DOTALL
)

# 6. Fix Kanban Subtask Tiles glow removal and urgency border
kanban_subtask_replace = r'''
    int subtaskUrgency = _getUrgency(s.endDate, s.status);
    final theme = Theme.of(context);
    final chosenColor = s.color ?? taskColor;

    return GestureDetector(
      onTap: () => _openSubtaskEditor(s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDone ? theme.cardTheme.color : chosenColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subtaskUrgency == 2 ? Colors.red : (subtaskUrgency == 1 ? Colors.amber : Colors.transparent),
            width: subtaskUrgency > 0 ? 2.0 : 0.0,
          ).copyWith(
            left: BorderSide(color: isDone ? theme.dividerColor : chosenColor, width: 6),
          ),
          boxShadow: subtaskUrgency == 2 ? [
            BoxShadow(color: Colors.red.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 4, offset: const Offset(0, 4))
          ] : [],
        ),
'''
code = re.sub(
    r'    final theme = Theme.of\(context\);\n    final chosenColor = s.color \?\? taskColor;\n\n    return GestureDetector\(\n      onTap: \(\) => _openSubtaskEditor\(s\),\n      behavior: HitTestBehavior.opaque,\n      child: AnimatedContainer\(\n.*?boxShadow: .*?\n        \),',
    kanban_subtask_replace.strip('\n'),
    code,
    count=1,
    flags=re.DOTALL
)


with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)

