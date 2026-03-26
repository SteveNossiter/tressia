import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Update _getUrgency logic: strictly Gold for <3 days future, Red for any past (not done)
new_get_urgency = """
  int _getUrgency(DateTime endDate, TaskStatus status) {
    if (status == TaskStatus.done) return 0;
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 2; // RED (Overdue)
    // ONLY gold if in the future AND within 3 days
    if (endDate.isAfter(now) && endDate.difference(now).inHours <= 72) return 1; // GOLD
    return 0;
  }
"""
code = re.sub(r'int _getUrgency\(DateTime endDate, TaskStatus status\) {.*?}\n', new_get_urgency.strip() + '\n', code, flags=re.DOTALL)

# 2. Make Kanban Task Tile Colors bolder (higher opacity)
# Find the task card BoxDecoration color logic
# Current: color: allDone ? theme.scaffoldBackgroundColor : t.color.withValues(alpha: 0.05),
# New: alpha: 0.15 (bolder background)
code = re.sub(
    r'color: allDone\s*\?\s*theme\.scaffoldBackgroundColor\s*:\s*t\.color\.withValues\(alpha: 0\.05\),',
    r'color: allDone ? theme.scaffoldBackgroundColor : t.color.withValues(alpha: 0.15),',
    code
)

# 3. Make Kanban Subtask Card Colors bolder
# Current: color: isDone ? theme.cardTheme.color : chosenColor.withValues(alpha: 0.1),
# New: alpha: 0.2
code = re.sub(
    r'color:\s*isDone\s*\?\s*theme\.cardTheme\.color\s*:\s*chosenColor\.withValues\(alpha: 0\.1\),',
    r'color: isDone ? theme.cardTheme.color : chosenColor.withValues(alpha: 0.25),',
    code
)

# 4. Clarify "ticked off" state (Greyed out) - already mostly there but ensuring colors
# Ensure text color for "allDone" or "isDone" is clearly greyed out.
# This was already: color: allDone ? theme.hintColor : theme.colorScheme.onSurface,

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
