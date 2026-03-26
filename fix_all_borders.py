import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Fix _buildDayRow borders to handle urgency transparency
# We'll replace the border block in BoxDecoration
code = re.sub(
    r'(border: urgency > 0\s*\? Border\.all\(\s*color: urgency == 2\s*\? Colors\.red\s*:\s*Colors\.amber,\s*width: 2\.0,\s*\)\s*:\s*)null,',
    r'\1Border.all(color: Colors.transparent, width: 0.0),',
    code
)

# 2. Fix _buildGanttRow borders (same logic)
# This was already applied by the logic above if the snippets were identical, 
# but let's be safe and check the exact pattern for _buildGanttRow if different.

# 3. Fix _buildKanbanGroups task tiles
# Find the Border.all in the task card mapping
# Pattern: color: taskUrgency == 2 ? Colors.red : (taskUrgency == 1 ? Colors.amber : (allDone ? ... : ...)),
# We need to ensure that the width is 0 if urgency is 0 but we keep Border.all for simplicity or just keep width 1.0 but color transparent?
# Actually, the error "hairline border ... only drawn when BorderRadius is zero or null" 
# means we shouldn't use width 0.0 with BorderRadius unless it's genuinely zero.
# So if we want "no border", we should use width 1.0 and color transparent, OR just use uniform color.

# Let's replace the logic to always use 2.0 width if urgency > 0, and 1.0 width otherwise.
# But if it's 1.0 width, it MUST have a color. If we want it "hidden", we use transparent.

# Refined fix for all Border.all that might have width 0 or null border
# Find: width: urgency > 0 ? 2.0 : 0.0
code = re.sub(r'width: ([\w]+)Urgency > 0 \? 2\.0 : 0\.0', r'width: \1Urgency > 0 ? 2.0 : 1.0', code)
code = re.sub(r'width: urgency > 0 \? 2\.0 : 0\.0', r'width: urgency > 0 ? 2.0 : 1.0', code)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
