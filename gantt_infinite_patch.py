import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. State changes
state_setup = '''
  final ScrollController _ganttHorizontalScroll = ScrollController();
  final ValueNotifier<String> _ganttTitleNotifier = ValueNotifier('');
  
  @override
  void initState() {
    super.initState();
    _ganttTitleNotifier.value = _getGanttTitle(_ganttAnchorDate);
  }

  @override
  void dispose() {
    _ganttHorizontalScroll.dispose();
    _ganttTitleNotifier.dispose();
    super.dispose();
  }
'''
if "final ValueNotifier<String> _ganttTitleNotifier" not in content:
    content = content.replace("bool _isFullscreenGantt = false;", "bool _isFullscreenGantt = false;\n" + state_setup)

# 2. _getGanttTitle
content = re.sub(r'String _getGanttTitle\(\) \{', r'String _getGanttTitle(DateTime date) {', content)
content = re.sub(r'_ganttAnchorDate', r'date', content)
# Wait, replacing all _ganttAnchorDate in the file is wrong!
# I will only replace it inside the _getGanttTitle method
title_logic = '''
  String _getGanttTitle(DateTime date) {
    if (this == null) return ''; // Safely bail
    final m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (_ganttScale) {
      case GanttScale.day:
        return '${d[date.weekday - 1]} ${date.day} ${m[date.month - 1]} ${date.year}';
      case GanttScale.week:
        int wd = date.weekday % 7; 
        DateTime ws = date.subtract(Duration(days: wd));
        DateTime we = ws.add(const Duration(days: 6));
        return '${ws.day} ${m[ws.month - 1]} - ${we.day} ${m[we.month - 1]} ${we.year}';
      case GanttScale.month:
        return '${m[date.month - 1]} ${date.year}';
      case GanttScale.year:
        return '${date.year}';
    }
  }

  void _updateGanttTitleFromScroll(double offset, double unitWidth, DateTime startAnchor, GanttScale scale) {
    if (unitWidth <= 0) return;
    double unitsScrolled = offset / unitWidth;
    DateTime visibleDate = startAnchor;
    
    if (scale == GanttScale.day) {
      visibleDate = startAnchor.add(Duration(hours: unitsScrolled.toInt()));
    } else {
      visibleDate = startAnchor.add(Duration(days: unitsScrolled.toInt()));
    }
    
    String newTitle = _getGanttTitle(visibleDate);
    if (_ganttTitleNotifier.value != newTitle) {
      _ganttTitleNotifier.value = newTitle;
    }
  }
'''
content = re.sub(r'String _getGanttTitle\(\) \{.*?\}\n\s*\}\n', title_logic, content, flags=re.DOTALL)


# 3. Gantt Header Text
content = re.sub(
    r'child: Text\(\n\s*_getGanttTitle\(.*?\),\n\s*style: GoogleFonts.outfit\(',
    r'child: ValueListenableBuilder<String>(\n                  valueListenable: _ganttTitleNotifier,\n                  builder: (context, title, _) => Text(\n                    title,\n                    style: GoogleFonts.outfit(',
    content
)
# Close bracket for ValueListenableBuilder (2 extra spaces for indenting)
content = re.sub(
    r'color: theme\.primaryColor,\n\s*\),\n\s*\),',
    r'color: theme.primaryColor,\n                    ),\n                  ),\n                ),',
    content
)

# Set states
content = re.sub(r'_ganttAnchorDate = DateTime\.now\(\)', r'_ganttAnchorDate = DateTime.now(); _ganttTitleNotifier.value = _getGanttTitle(_ganttAnchorDate)', content)
# navigate Gantt
content = re.sub(r'_ganttAnchorDate = DateTime\(\_ganttAnchorDate\.year \+ direction, 1, 1\);\n\s*break;\n\s*\}\n\s*\}\);',
    r'_ganttAnchorDate = DateTime(_ganttAnchorDate.year + direction, 1, 1);\n          break;\n      }\n      _ganttTitleNotifier.value = _getGanttTitle(_ganttAnchorDate);\n    });', content)

# 4. Gantt Notification Listener
content = re.sub(
    r'Expanded\(\n\s*child: SingleChildScrollView\(\n\s*scrollDirection: Axis\.horizontal,',
    r'Expanded(\n              child: NotificationListener<ScrollNotification>(\n                onNotification: (notif) {\n                  if (notif is ScrollUpdateNotification) {\n                    _updateGanttTitleFromScroll(notif.metrics.pixels, unitWidth, startAnchor, scale);\n                  }\n                  return false;\n                },\n                child: SingleChildScrollView(\n                  controller: _ganttHorizontalScroll,\n                  scrollDirection: Axis.horizontal,',
    content
)
# Add an extra bracket to close NotificationListener
content = re.sub(
    r'\n\s*\]\,\n\s*\)\,\n\s*\)\,\n\s*\)\,\n\s*\]\,\n\s*\)\,\n\s*\)\,\n\s*\)\;',
    r'\n                    ],\n                  ),\n                ),\n              ),\n            ),\n          ],\n        ),\n      ),\n    );',
    content
)

# 5. Grid logic for all view modes
grid_bolder_logic = '''
                          bool isBolder = false;
                          bool isDrawn = true;
                          
                          if (scale == GanttScale.month) {
                            DateTime d = startAnchor.add(Duration(days: i));
                            if (d.weekday == 1) isBolder = true; // Monday
                          } else if (scale == GanttScale.year) {
                            DateTime d = startAnchor.add(Duration(days: i));
                            if (d.day == 1) {
                              isBolder = true; // Month
                            } else if (d.weekday == 1) {
                              isBolder = false; // Week
                            } else {
                              isDrawn = false; // Empty day
                            }
                          }
                          
                          return Container(
                            width: unitWidth,
                            decoration: (!isDrawn) ? null : BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: theme.dividerColor.withValues(alpha: isBolder ? 0.3 : 0.05),
                                  width: isBolder ? 1.5 : 1.0
                                )
'''
content = re.sub(r'bool isBolder = false;.*?border: Border\(\s*left: BorderSide\(\s*color: theme\.dividerColor\.withValues\(alpha: isBolder \? 0\.2 : 0\.05\),\s*width: isBolder \? 1\.5 : 1\.0\s*\)', grid_bolder_logic, content, flags=re.DOTALL)


# 6. Infinite SCROLL unit recalculations (Day, Week, Month, Year buffers)
content = re.sub(r'unitWidth = \(timelineWidth / totalUnits\)\.clamp\(40\.0, double\.infinity\);', r'unitWidth = 60.0;', content)
content = re.sub(r'unitWidth = \(timelineWidth / totalUnits\)\.clamp\(60\.0, double\.infinity\);', r'unitWidth = 60.0;', content)
content = re.sub(r'unitWidth = \(timelineWidth / totalUnits\)\.clamp\(30\.0, double\.infinity\);', r'unitWidth = 30.0;', content)

# Week 
infinite_week_logic = '''
    } else if (scale == GanttScale.week) {
      int offsetWeeks = 10;
      totalUnits = 7 * (offsetWeeks * 2 + 1); 
      unitWidth = 60.0;
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
content = re.sub(r'\} else if \(scale == GanttScale\.week\) \{.*?\}\s*\} else if \(scale == GanttScale\.month\) \{', infinite_week_logic + '    } else if (scale == GanttScale.month) {', content, flags=re.DOTALL)

# Month
infinite_month_logic = '''
    } else if (scale == GanttScale.month) {
      int offsetMonths = 3;
      int numMonths = offsetMonths * 2 + 1;
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month - offsetMonths, 1);
      int totalDays = 0;
      for (int m = 0; m < numMonths; m++) { totalDays += DateTime(startAnchor.year, startAnchor.month + m + 1, 0).day; }
      totalUnits = totalDays;
      unitWidth = 40.0; 
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
content = re.sub(r'\} else if \(scale == GanttScale\.month\) \{.*?\}\s*\} else if \(scale == GanttScale\.year\) \{', infinite_month_logic + '    } else if (scale == GanttScale.year) {', content, flags=re.DOTALL)

# Year
infinite_year_logic = '''
    } else if (scale == GanttScale.year) {
      int offsetYears = 1;
      int numYears = offsetYears * 2 + 1;
      startAnchor = DateTime(_ganttAnchorDate.year - offsetYears, 1, 1);
      int totalDays = 0;
      for (int i = 0; i < numYears * 12; i++) {
         int y = startAnchor.year + (i ~/ 12);
         int m = (i % 12) + 1;
         totalDays += DateTime(y, m + 1, 0).day;
      }
      totalUnits = totalDays; 
      unitWidth = 5.0; // Very squished per day
      
      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(Duration(days: totalUnits)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }
      
      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 0; i < numYears * 12; i++) {
        int y = startAnchor.year + (i ~/ 12);
        int mId = (i % 12);
        DateTime headerDate = DateTime(y, mId + 1, 1);
        int daysInMonth = DateTime(y, mId + 2, 0).day; 
        bool isNow = now.year == y && now.month == mId + 1;
        headerWidgets.add(_buildHeaderCell(months[mId] + ' ' + y.toString(), isNow, unitWidth * daysInMonth, theme));
      }
    }
'''
content = re.sub(r'\} else if \(scale == GanttScale\.year\) \{.*?\double maxTotalWidth', infinite_year_logic + '\n    double maxTotalWidth', content, flags=re.DOTALL)

# Day -> Day is also infinite?
infinite_day_logic = '''
    if (scale == GanttScale.day) {
      int offsetDays = 3;
      totalUnits = (offsetDays * 2 + 1) * 24; 
      unitWidth = 60.0;
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month, _ganttAnchorDate.day - offsetDays, 0);

      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(Duration(hours: totalUnits)))) {
         currentPos = (now.difference(startAnchor).inMinutes / 60.0) * unitWidth;
      }
      for (int i = 0; i < totalUnits; i++) {
        DateTime d = startAnchor.add(Duration(hours: i));
        bool isNow = now.year == d.year && now.month == d.month && now.day == d.day && now.hour == d.hour;
        int h = d.hour;
        String label = h == 0 ? '12am' : h < 12 ? '${h}am' : h == 12 ? '12pm' : '${h - 12}pm';
        headerWidgets.add(_buildHeaderCell(label, isNow, unitWidth, theme));
      }
'''
content = re.sub(r'if \(scale == GanttScale\.day\) \{.*?\}\s*\} else if \(scale == GanttScale\.week\) \{', infinite_day_logic + '    } else if (scale == GanttScale.week) {', content, flags=re.DOTALL)


with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
