import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/project_module.dart';
import '../providers/app_state.dart';
import 'dialogs/glass_dialog.dart';
import 'dialogs/task_editor.dart';
import 'dialogs/subtask_editor.dart';

class BlockCalendar extends ConsumerStatefulWidget {
  final List<ProjectTask> tasks;
  const BlockCalendar({Key? key, required this.tasks}) : super(key: key);

  @override
  _BlockCalendarState createState() => _BlockCalendarState();
}

class _BlockCalendarState extends ConsumerState<BlockCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<dynamic> _getEventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final tasks = widget.tasks;
    final subtasks = ref.read(subtasksProvider);

    List<dynamic> events = [];
    for (var t in tasks) {
      if (t.startDate.isBefore(dayEnd) && t.endDate.isAfter(dayStart))
        events.add(t);
    }
    for (var s in subtasks) {
      if (s.startDate.isBefore(dayEnd) && s.endDate.isAfter(dayStart))
        events.add(s);
    }
    return events;
  }

  List<Color> _getColorsForDay(DateTime day) {
    final events = _getEventsForDay(day);
    final colors = <Color>{};
    for (var e in events) {
      if (e is ProjectTask) colors.add(e.color);
      if (e is Subtask) colors.add(e.color ?? Colors.grey);
    }
    return colors.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        TableCalendar<dynamic>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          }),
          eventLoader: _getEventsForDay,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (ctx, day, events) {
              if (events.isEmpty) return null;
              final colors = _getColorsForDay(day);
              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: colors
                      .map(
                        (c) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            markersMaxCount: 0,
            todayDecoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.primaryColor,
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: theme.primaryColor,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: theme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedDay == null
              ? Center(
                  child: Text(
                    'Select a day to view events',
                    style: GoogleFonts.outfit(color: theme.hintColor),
                  ),
                )
              : _buildEventList(theme),
        ),
      ],
    );
  }

  Widget _buildEventList(ThemeData theme) {
    final events = _getEventsForDay(_selectedDay!);
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events',
          style: GoogleFonts.outfit(color: theme.hintColor),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: events.map((e) {
        if (e is ProjectTask) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: e.color.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: e.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(
                e.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                'Task • ${e.status.name}',
                style: GoogleFonts.outfit(fontSize: 11, color: theme.hintColor),
              ),
              trailing: Icon(
                e.status == TaskStatus.done
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: e.color,
                size: 20,
              ),
              onTap: () => showGlassDialog(context, TaskEditor(task: e)),
            ),
          );
        } else if (e is Subtask) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: (e.color ?? Colors.grey).withValues(alpha: 0.2),
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: e.color ?? theme.hintColor,
              ),
              title: Text(e.title, style: GoogleFonts.outfit(fontSize: 12)),
              subtitle: Text(
                'Subtask • ${e.status.name}',
                style: GoogleFonts.outfit(fontSize: 10, color: theme.hintColor),
              ),
              onTap: () => showGlassDialog(context, SubtaskEditor(subtask: e)),
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
