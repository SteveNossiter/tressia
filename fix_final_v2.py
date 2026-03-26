import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    text = f.read()

# Replace the messy tail of _buildMonthView/WeekView header loop.
# From the BoxDecoration for the hairline border to the closing of the header loop.
# This pattern matches from Container( height: today ? 2 : 1, width: dayWidth - 8, ... until projects.expand
# based on we saw in previous grep.
bad = r'Container\(\s+height: today \? 2 : 1,.*?\}\)\,\s+\],\s+\),\s+\),\s+\);\s+\}\)\,\s+\],\s+\),\s+const SizedBox\(height: 16\)\,'
# I'll use a safer string slice for line 1239 roughly.

# Replace line 1239 '], ' with something else? 
# Wait, the error was "rt:1239:7: Error: Expected ')' before this.      ], "
# and 1064 context too.

# THE MOST LIKELY REASON FOR ref, _collapsedKanbanPhases etc being undefined 
# is that _buildKanbanGroups is now sitting OUTSIDE the _DashboardScreenState class.
# We need to find the premature closing '}' above it.

# Look for '  Widget _buildGanttRow(' or similar that may have extra '}' before it.
# Or '  Widget _buildGanttChart(' 

# Let's find the closing brace of build()
marker = "    );\n  }\n\n  // ====================================================="
# Wait, if I see '  }\n\n  // =====================================================' 
# usually there is ONE '}' for the build() method.
# If there is TWO '}', then the class closed.

if "    );\n  }\n}" in text:
    print("Found premature class close")
    text = text.replace("    );\n  }\n}", "    );\n  }")

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(text)
