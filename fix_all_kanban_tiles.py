import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Replace the entire Task Card Mapping loop block to avoid mix-and-match border/radius error
# AND ensure we have the IntrinsicHeight structural fix.

new_task_mapping = """
                      children: pTasks.map((t) {
                        var tSubs = subtasks
                            .where((s) => s.taskId == t.id)
                            .toList();
                        tSubs.sort((a, b) => a.endDate.compareTo(b.endDate));
                        bool allDone = tSubs.isNotEmpty &&
                            tSubs.every((s) => s.status == TaskStatus.done);
                        bool isTaskCollapsed =
                            _collapsedKanbanTasks.contains(t.id);

                        int taskUrgency = _getUrgency(t.endDate, t.status);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: taskUrgency == 2
                                  ? Colors.red
                                  : (taskUrgency == 1
                                      ? Colors.amber
                                      : (allDone
                                          ? theme.dividerColor
                                              .withValues(alpha: 0.2)
                                          : Colors.transparent)),
                              width: taskUrgency > 0 ? 2.0 : 1.0,
                            ),
                            color: allDone
                                ? theme.scaffoldBackgroundColor
                                : t.color.withValues(alpha: 0.25),
                            boxShadow: taskUrgency == 2
                                ? [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.8),
                                      blurRadius: 16,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 6,
                                  color: allDone ? theme.dividerColor : t.color,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _openTaskEditor(t),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.transparent,
                                          child: Row(
                                            children: [
                                              Icon(
                                                allDone
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: allDone
                                                    ? theme.dividerColor
                                                    : t.color,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  t.title,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    textStyle: TextStyle(
                                                      decoration: allDone
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                    color: allDone
                                                        ? theme.hintColor
                                                        : theme.colorScheme
                                                            .onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (tSubs.isNotEmpty)
                                                GestureDetector(
                                                  onTap: () => setState(() {
                                                    if (isTaskCollapsed) {
                                                      _collapsedKanbanTasks
                                                          .remove(t.id);
                                                    } else {
                                                      _collapsedKanbanTasks
                                                          .add(t.id);
                                                    }
                                                  }),
                                                  child: Icon(
                                                    isTaskCollapsed
                                                        ? Icons.expand_more
                                                        : Icons.expand_less,
                                                    color: theme.hintColor,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!isTaskCollapsed && tSubs.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 16),
                                          child: Column(
                                            children: tSubs
                                                .map((s) =>
                                                    _buildKanbanSubtaskCard(
                                                        context, s, t.color))
                                                .toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
"""

# Pattern to replace from pTasks.map until its toList()
pattern = r"children: pTasks\.map\(\(t\) \{(.*?)toList\(\),"
# Using re.DOTALL to match multiline
code = re.sub(pattern, new_task_mapping, code, flags=re.DOTALL)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
