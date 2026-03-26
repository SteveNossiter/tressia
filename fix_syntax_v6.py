import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    code = f.read()

# 1. Very specific string replacement for the messy block
old_messy = """                        Container(
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
                      ),
                    ),
                  );
            }),"""

new_clean = """                        Container(
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

code = code.replace(old_messy, new_clean)

# 2. Fix _buildKanbanGroups call site
# Use exact string replacement to be safe
old_call = """            ..._buildKanbanGroups(
              context,
              filteredProjects,
              filteredTasks,
              filteredSubtasks,
            ),"""

new_call = """            ..._buildKanbanGroups(
              context,
              filteredProjects,
              filteredTasks,
              filteredSubtasks,
            ),"""
# wait, the old call IN the file was:
# ..._buildKanbanGroups(context, filteredProjects, filteredTasks, filteredSubtasks,),
# according to the error message (too many positional arguments: 1 allowed)
# This means the current call looks like it has 4, but the method only expects 1?
# No, the error said "Too many positional arguments: 1 allowed, but 4 found" 
# which means the version CURRENTLY in the file 
# at line 310 has 4 arguments, but the METHOD at 1975 only had 1 in the PREVIOUS BROKEN VERSION.
# But I REPLACED it at 1975 with a 4-arg version.
# Let me check the call site at 310 again.

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(code)
