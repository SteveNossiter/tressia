import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# Replace the Entire _buildKanbanSubtaskCard to ensure no Border(...) exists
# AND make the background even bolder
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
              : chosenColor.withValues(alpha: 0.35),
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
                                    : FontWeight.w600,
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
                                fontWeight: FontWeight.bold,
                                color: isDone 
                                    ? theme.hintColor 
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

# 1. Update Subtask Card logic
code = re.sub(r'Widget _buildKanbanSubtaskCard\(.*?}\n}\s*$', new_subtask_card, code, flags=re.DOTALL)

# 2. Update Task Tile (pTasks.map) logic for bold background and bolder text
code = re.sub(
    r'color: allDone \? theme\.scaffoldBackgroundColor : t\.color\.withValues\(alpha: 0\.15\),',
    r'color: allDone ? theme.scaffoldBackgroundColor : t.color.withValues(alpha: 0.25),',
    code
)

# Replace task title text style to be bolder
code = re.sub(
    r'fontWeight: FontWeight\.w600,',
    r'fontWeight: FontWeight.w700,',
    code
)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
