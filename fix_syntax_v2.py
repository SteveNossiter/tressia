import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# Match the messy part from 2200 to 'if (grouped.isEmpty'
# We'll just replace that whole tail of the function.
# The grouped list was added items in a loop.
# grouped.add( AnimatedContainer( ... ) ); - wait, did I lose the grouped.add call?

# Let's fix the entire _buildKanbanGroups method content to be safe.
new_kanban_groups = """
  List<Widget> _buildKanbanGroups(Map<String, List<ProjectTask>> groupedByPhase) {
    final theme = Theme.of(context);
    List<Widget> grouped = [];
    
    // Convert map to entries and sort by phase order (you might need to ensure order)
    var entries = groupedByPhase.entries.toList();
    
    for (var entry in entries) {
      String phaseId = entry.key;
      List<ProjectTask> pTasks = entry.value;
      
      var p = phases.firstWhere((ph) => ph.id == phaseId,
          orElse: () => ProjectPhase(
              id: phaseId,
              title: "Unknown Phase",
              projectId: widget.projectId,
              startDate: DateTime.now(),
              endDate: DateTime.now()));
      
      bool isCollapsed = _collapsedKanbanPhases.contains(p.id);
      
      grouped.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: theme.cardTheme.color?.withValues(alpha: 0.5) ??
                theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  if (isCollapsed)
                    _collapsedKanbanPhases.remove(p.id);
                  else
                    _collapsedKanbanPhases.add(p.id);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.phaseColors[
                              phases.indexOf(p) % AppTheme.phaseColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          p.title.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                      Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 22,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
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
                  ),
                ),
            ],
          ),
        ),
      );
    }
"""

# Replace the whole method from signature until the return grouped line
pattern = r'List<Widget> _buildKanbanGroups\(.*?\}\n\s+if \(grouped\.isEmpty'
code = re.sub(pattern, new_kanban_groups + '\n\n    if (grouped.isEmpty', code, flags=re.DOTALL)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
