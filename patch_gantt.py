import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. Landscape phone trigger
content = re.sub(
    r'if \(_isFullscreenGantt\) \{',
    r'bool isLandscapePhone = MediaQuery.of(context).orientation == Orientation.landscape && MediaQuery.of(context).size.height < 600;\n    if (_isFullscreenGantt || isLandscapePhone) {',
    content
)

# 2. Fix Fullscreen layout crash
# In `_isFullscreenGantt` block, it returns `Expanded(child: SingleChildScrollView(child: _buildGanttChart(...)))`
# But _buildGanttChart returns Expanded too!
content = re.sub(
    r'Expanded\(\s*child:\s*SingleChildScrollView\(\s*child:\s*_buildGanttChart\(',
    r'Expanded(\n                child: _buildGanttChart(',
    content
)

# 3. Fix _buildGanttChart returning Expanded
# We want to change the shouldBeFullscreen logic inside _buildGanttChart.
res = re.search(r'bool shouldBeFullscreen = _isFullscreenGantt \|\| isLandscapePhone;', content)
if res:
    content = content.replace(
        'bool shouldBeFullscreen = _isFullscreenGantt || isLandscapePhone;',
        'bool isLandscapePhone = MediaQuery.of(context).orientation == Orientation.landscape && MediaQuery.of(context).size.height < 600;\n    bool shouldBeFullscreen = _isFullscreenGantt || isLandscapePhone;'
    )

content = re.sub(
    r'return Expanded\(child: ganttContent\);\s*// Fill space in fullscreen',
    r'return ganttContent; // It is already inside an Expanded in the parent!',
    content
)

# 4. Modify mobile label width and grid lines
content = re.sub(
    r'const double labelWidth = 150;',
    r'double labelWidth = availableWidth < 600 ? 80 : 150;',
    content
)

# 5. Text overlap fix and grid height fix
content = re.sub(
    r'Row\(\s*children: List\.generate\(totalUnits, \(i\) \{',
    r'Positioned.fill(\n                      child: Row(\n                        children: List.generate(totalUnits, (i) {',
    content
)
content = re.sub(
    r'width: isBolder \? 1\.5 : 1\.0\n                                \)\n                              \)\n                            \),\n                          \);\n                        \}\),\n                      \),',
    r'width: isBolder ? 1.5 : 1.0\n                                )\n                              )\n                            ),\n                          );\n                        }),\n                      ),\n                    ),',
    content
)

# 6. Infinite SCROLL logic + Dynamic Selection Text
# "Make the gantt horizontally scrollable indefinitely, changing the selection text above to match currently displaying selection."
# I will use a larger buffer for GanttScale.week to make it scrollable across many weeks.
infinite_week_logic = '''
    } else if (scale == GanttScale.week) {
      int offsetWeeks = 4;
      totalUnits = 7 * (offsetWeeks * 2 + 1); // 9 weeks total
      unitWidth = (timelineWidth / 7).clamp(60.0, double.infinity);
      int weekday = _ganttAnchorDate.weekday;
      startAnchor = _ganttAnchorDate.subtract(Duration(days: weekday - 1 + (offsetWeeks * 7)));
      startAnchor = DateTime(startAnchor.year, startAnchor.month, startAnchor.day);
      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(Duration(days: totalUnits)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }
      final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < totalUnits; i++) {
        DateTime dayDate = startAnchor.add(Duration(days: i));
        bool isNow = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
        String dayName = days[dayDate.weekday - 1];
        headerWidgets.add(_buildHeaderCell('${dayName} ${dayDate.day}', isNow, unitWidth, theme));
      }
'''
content = re.sub(
    r'\} else if \(scale == GanttScale\.week\) \{.*?\}\s*\} else if \(scale == GanttScale\.month\) \{',
    infinite_week_logic + '    } else if (scale == GanttScale.month) {',
    content,
    flags=re.DOTALL
)

# 7. Same for day, month, year scaling (give a nice buffer!)
infinite_month_logic = '''
    } else if (scale == GanttScale.month) {
      int offsetMonths = 3;
      int numMonths = offsetMonths * 2 + 1;
      
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month - offsetMonths, 1);
      int totalDays = 0;
      for (int m = 0; m < numMonths; m++) {
        totalDays += DateTime(startAnchor.year, startAnchor.month + m + 1, 0).day;
      }
      totalUnits = totalDays;
      unitWidth = (timelineWidth / 30).clamp(30.0, double.infinity); 
      
      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(Duration(days: totalUnits)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }
      for (int i = 0; i < totalUnits; i++) {
        DateTime d = startAnchor.add(Duration(days: i));
        bool isNow = now.year == d.year && now.month == d.month && now.day == d.day;
        headerWidgets.add(_buildHeaderCell('${d.day}', isNow, unitWidth, theme));
      }
'''
content = re.sub(
    r'\} else if \(scale == GanttScale\.month\) \{.*?\}\s*\} else if \(scale == GanttScale\.year\) \{',
    infinite_month_logic + '    } else if (scale == GanttScale.year) {',
    content,
    flags=re.DOTALL
)

content = re.sub(r'Padding\(\n\s*padding: const EdgeInsets\.symmetric\(horizontal: 8\),\n\s*child: Align\(\n\s*alignment: extendsLeft \? Alignment\.centerRight : Alignment\.centerLeft,',
   r'Transform.translate(\n                  offset: Offset(extendsLeft || width < 60 ? -120 : 0, 0),\n                  child: Padding(\n                  padding: const EdgeInsets.symmetric(horizontal: 8),\n                  child: Align(\n                    alignment: extendsLeft || width < 60 ? Alignment.centerRight : Alignment.centerLeft,',
   content)

with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)

