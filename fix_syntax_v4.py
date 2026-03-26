import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Fix the double-mapping error in _buildWeekView (around 1310)
# We need to find the specific block and replace it.
# The code seems to have an extra ');' or similar.

# 2. Fix _buildKanbanGroups call site (at line 310)
# old: ..._buildKanbanGroups(context, filteredProjects, filteredTasks, filteredSubtasks,),
# new (ensure exactly these 4 arguments):
code = re.sub(
    r'\.\.\._buildKanbanGroups\(.*?\),',
    r'..._buildKanbanGroups(context, filteredProjects, filteredTasks, filteredSubtasks),',
    code,
    flags=re.DOTALL
)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
