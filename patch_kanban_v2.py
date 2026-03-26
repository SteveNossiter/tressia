import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# Define the new content for _buildKanbanSubtaskCard - NO BORDER Side on outer Box
new_subtask_card = """
  Widget _buildKanbanSubtaskCard(
    BuildContext context,
    Subtask s,
    Color taskColor,
  ) {
    final theme = Theme.of(context);
    final isDone = s.status == TaskStatus.done;
    final chosenColor = s.color ?? taskColor;

    int subtaskUrgency = _getUrgency(s.endDate, s.status);

    return GestureDetector(
      onTap: () => _openSubtaskEditor(s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDone
              ? theme.cardTheme.color
              : chosenColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subtaskUrgency == 2
                ? Colors.red
                : (subtaskUrgency == 1 ? Colors.amber : Colors.transparent),
            width: subtaskUrgency > 0 ? 2.0 : 1.0,
          ),
          boxShadow: subtaskUrgency == 2
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: isDone ? theme.dividerColor : chosenColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: isDone ? theme.dividerColor : chosenColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: GoogleFonts.outfit(
                                fontWeight: isDone
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? theme.hintColor
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Due: ${s.endDate.day}/${s.endDate.month}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: theme.hintColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (s.assignedUserId != 'unassigned')
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.purple.withValues(alpha: 0.5),
                          child: const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

# Replace the existing _buildKanbanSubtaskCard method
code = re.sub(r'Widget _buildKanbanSubtaskCard\(.*?}\n}\s*$', new_subtask_card, code, flags=re.DOTALL)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
