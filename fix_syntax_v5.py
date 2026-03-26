import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Fix the double-mapping error in _buildWeekView (lines 1307-1312)
# The current code has extra closing braces/brackets.
bad_block = r"borderRadius: BorderRadius\.circular\(1\),\n\s+\),\n\s+\),\n\s+\],\n\s+\),\n\s+\),\n\s+\),\n\s+\);\n\s+\}\)\,"
# Actually, looking at 1306-1311:
# 1306:                       ),
# 1307:                                   ],
# 1308:                         ),
# 1309:                       ),
# 1310:                     ),
# 1311:                   );
# 1312:             }),
# Correct structure:
# Column([ ..., Container(...) ]) 
# )  // Padding/Container
# )  // SizedBox/GestureDetector

# Let's replace the whole children: List.generate for dayHeaders
headers_replacement_v5 = r"""children: List.generate(7, (i) {
                  final day = weekStart.add(Duration(days: i));
                  final today = DateTime.now().day == day.day &&
                      DateTime.now().month == day.month &&
                      DateTime.now().year == day.year;
                  return SizedBox(
                    width: dayWidth,
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(day).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: today ? theme.primaryColor : theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.day.toString(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: today
                                ? theme.primaryColor
                                : theme.hintColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: today ? 2 : 1,
                          width: dayWidth - 8,
                          decoration: BoxDecoration(
                            color: today
                                ? theme.primaryColor
                                : theme.dividerColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  );
                }),"""

# Use a very specific regex for the messy block
pattern_v5 = r"children: List\.generate\(7, \(i\) \{.*?\}\)\,"
code = re.sub(pattern_v5, headers_replacement_v5, code, flags=re.DOTALL)

# 2. Fix _buildKanbanGroups call site (at line 310)
# Ensure only it contains strictly 4 arguments
code = re.sub(
    r'\.\.\._buildKanbanGroups\(.*?\)\s*,',
    r'..._buildKanbanGroups(context, filteredProjects, filteredTasks, filteredSubtasks),',
    code,
    flags=re.DOTALL
)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
