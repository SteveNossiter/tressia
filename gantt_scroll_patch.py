import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. Add ValueNotifier and ScrollController to _DashboardScreenState
state_setup = '''
  final Set<String> _collapsedGanttTasks = {};

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
  
  String _getGanttTitle(DateTime date) {
    final m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (_ganttScale) {
      case GanttScale.day:
        return '${d[date.weekday - 1]} ${date.day} ${m[date.month - 1]} ${date.year}';
      case GanttScale.week:
        DateTime ws = date.subtract(Duration(days: date.weekday % 7));
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
    } else if (scale == GanttScale.week || scale == GanttScale.month) {
      visibleDate = startAnchor.add(Duration(days: unitsScrolled.toInt()));
    } else if (scale == GanttScale.year) {
      visibleDate = startAnchor.add(Duration(days: unitsScrolled.toInt()));
    }
    
    String newTitle = _getGanttTitle(visibleDate);
    if (_ganttTitleNotifier.value != newTitle) {
      _ganttTitleNotifier.value = newTitle;
    }
  }
'''

content = re.sub(
    r'final Set<String> _collapsedGanttTasks = \{\};.*?// Row counter',
    state_setup + '\n  // Row counter',
    content,
    flags=re.DOTALL
)

# 2. Update _getGanttTitle calls to use _ganttTitleNotifier and _getGanttTitle(date)
content = re.sub(r'String _getGanttTitle\(\) \{.*?\}', '', content, flags=re.DOTALL)

# Header value listenable
content = re.sub(
    r'child: Text\(\n\s*_getGanttTitle\(\),',
    r'child: ValueListenableBuilder<String>(\n                  valueListenable: _ganttTitleNotifier,\n                  builder: (context, title, _) => Text(\n                  title,',
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

# 3. Add ScrollController and NotificationListener to Gantt chart
content = re.sub(
    r'Expanded\(\s*child: SingleChildScrollView\(\s*scrollDirection: Axis\.horizontal,',
    r'Expanded(\n              child: NotificationListener<ScrollNotification>(\n                onNotification: (notif) {\n                  if (notif is ScrollUpdateNotification) {\n                    _updateGanttTitleFromScroll(notif.metrics.pixels, unitWidth, startAnchor, scale);\n                  }\n                  return false;\n                },\n                child: SingleChildScrollView(\n                  controller: _ganttHorizontalScroll,\n                  scrollDirection: Axis.horizontal,',
    content
)
# Add an extra bracket to close NotificationListener
content = re.sub(
    r'\),\n\s*\],\n\s*\),\n\s*\),\n\s*\)\,\n\s*\],\n\s*\),\n\s*\),\n\s*\);',
    r'),\n                  ],\n                ),\n              ),\n            ),\n            ),\n          ],\n        ),\n      ),\n    );',
    content
)


# 4. Gantt grid fixes for Year Scale
# "In Year veiw: Each week seperated by a grid line, Each Month seperated by a stronger grid line."
year_view_grid = '''
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
      unitWidth = (timelineWidth / 365).clamp(5.0, double.infinity);
      
      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(Duration(days: totalUnits)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }
      
      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 0; i < numYears * 12; i++) {
        int y = startAnchor.year + (i ~/ 12);
        int mId = (i % 12);
        DateTime headerDate = DateTime(y, mId + 1, 1);
        int daysInMonth = DateTime(y, mId + 2, 0).day; // Number of days in this month
        
        bool isNow = now.year == y && now.month == mId + 1;
        headerWidgets.add(_buildHeaderCell(months[mId] + ' ' + y.toString(), isNow, unitWidth * daysInMonth, theme));
      }
    }
'''
content = re.sub(
    r'\} else if \(scale == GanttScale\.year\) \{.*?\double maxTotalWidth',
    year_view_grid + '\n    double maxTotalWidth',
    content, flags=re.DOTALL
)

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
                                  color: theme.dividerColor.withValues(alpha: isBolder ? 0.3 : 0.08),
                                  width: isBolder ? 1.5 : 1.0
                                )
'''
content = re.sub(r'bool isBolder = false;.*?border: Border\(\s*left: BorderSide\(\s*color: theme.dividerColor.withValues\(alpha: isBolder \? 0\.2 : 0\.05\),\s*width: isBolder \? 1\.5 : 1\.0\s*\)', grid_bolder_logic, content, flags=re.DOTALL)


with open('lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)

