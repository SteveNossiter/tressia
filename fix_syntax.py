import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# The pattern 2200-2210 is messy
# 2201: }).toList(),
# 2202: 
# 2203:             ),
# 2204:           ),
# 2205:       ],
# 2206:     ),
# 2207:   );
# 2208: }).toList(),

# Let's clean up the outer loops.
# Start from 2067 where Column children starts
# and replace until the end of that Column children (2209)

new_column_children = """
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
                      }).toList(),"""

# Regex is tricky due to the nested loops. 
# Let's match from 'children: pTasks.map' to the very end of that block.
# We'll use the fact that it ends with }).toList(), repeated or followed by Column closing.

pattern = r'children: pTasks\.map\(.*?\}\)\.toList\(\),'
code = re.sub(pattern, new_column_children, code, flags=re.DOTALL)

# Now clean up any doubled/garbage endings if they survived
code = re.sub(r'\}\)\.toList\(\),\s+\),\s+\),\s+\]\s+\),\s+\),\s+\}\)\.toList\(\),', r'}).toList(),', code, flags=re.DOTALL)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
