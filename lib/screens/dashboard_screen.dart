import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/project_module.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'client_profile_screen.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../widgets/dialogs/subtask_editor.dart';
import '../widgets/dialogs/task_editor.dart';
import '../widgets/dialogs/phase_editor.dart';
import '../widgets/dialogs/entity_creator.dart';
import 'package:tressia/screens/session_dashboard.dart';

enum GanttScale { day, week, month, year }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Kanban state
  final Set<String> _collapsedKanbanPhases = {};
  final Set<String> _collapsedKanbanTasks = {};

  // Search & Filters
  String _searchQuery = '';
  String _filterType = 'All'; // All, Client Course, Project
  String _filterStatus = 'All'; // All, Active, Completed, Cancelled
  String? _filterTherapistId;

  // Gantt state
  GanttScale _ganttScale = GanttScale.week;
  DateTime _ganttAnchorDate = DateTime.now();

  // Gantt collapse state
  final Set<String> _collapsedGanttPhases = {};
  final Set<String> _collapsedGanttTasks = {};

  // Row counter for alternating tints
  int _ganttRowIndex = 0;

  bool _isFullscreenGantt = false;

  // =====================================================
  // HELPERS
  // =====================================================
  void _toggleSubtask(Subtask s) {
    TaskStatus next;
    if (s.status == TaskStatus.todo)
      next = TaskStatus.inProgress;
    else if (s.status == TaskStatus.inProgress)
      next = TaskStatus.done;
    else
      next = TaskStatus.todo;
    ref.read(subtasksProvider.notifier).updateSubtask(s.copyWith(status: next));
  }

  void _openPhaseEditor(Project p) =>
      showGlassDialog(context, PhaseEditor(project: p));
  void _openTaskEditor(ProjectTask t) =>
      showGlassDialog(context, TaskEditor(task: t));
  void _openSubtaskEditor(Subtask s) =>
      showGlassDialog(context, SubtaskEditor(subtask: s));

  void _navigateGantt(int direction) {
    setState(() {
      switch (_ganttScale) {
        case GanttScale.day:
          _ganttAnchorDate = _ganttAnchorDate.add(Duration(days: direction));
          break;
        case GanttScale.week:
          _ganttAnchorDate = _ganttAnchorDate.add(
            Duration(days: 7 * direction),
          );
          break;
        case GanttScale.month:
          int m = _ganttAnchorDate.month + direction;
          int y = _ganttAnchorDate.year;
          if (m > 12) {
            m = 1;
            y++;
          }
          if (m < 1) {
            m = 12;
            y--;
          }
          _ganttAnchorDate = DateTime(y, m, 1);
          break;
        case GanttScale.year:
          _ganttAnchorDate = DateTime(_ganttAnchorDate.year + direction, 1, 1);
          break;
      }
    });
  }

  String _getGanttTitle() {
    final m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (_ganttScale) {
      case GanttScale.day:
        return '${d[_ganttAnchorDate.weekday - 1]} ${_ganttAnchorDate.day} ${m[_ganttAnchorDate.month - 1]} ${_ganttAnchorDate.year}';
      case GanttScale.week:
        DateTime ws = _ganttAnchorDate.subtract(
          Duration(days: _ganttAnchorDate.weekday % 7),
        );
        DateTime we = ws.add(const Duration(days: 6));
        return '${ws.day} ${m[ws.month - 1]} - ${we.day} ${m[we.month - 1]} ${we.year}';
      case GanttScale.month:
        return '${m[_ganttAnchorDate.month - 1]} ${_ganttAnchorDate.year}';
      case GanttScale.year:
        return '${_ganttAnchorDate.year}';
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _spansDay(DateTime start, DateTime end, DateTime day) {
    DateTime ds = DateTime(day.year, day.month, day.day);
    DateTime de = ds.add(const Duration(days: 1));
    return start.isBefore(de) && end.isAfter(ds);
  }

  double _getFraction(DateTime date, DateTime origin, int totalHours) {
    if (totalHours <= 0) return 0.0;
    return date.difference(origin).inMinutes / (totalHours * 60.0);
  }

  int _getUrgency(DateTime endDate, TaskStatus status) {
    if (status == TaskStatus.done) return 0;
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 2; // RED (Overdue)
    // ONLY gold if in the future AND within 3 days
    if (endDate.isAfter(now) && endDate.difference(now).inHours <= 72)
      return 1; // GOLD
    return 0;
  }

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final projects = ref.watch(projectsProvider);
    final subtasks = ref.watch(subtasksProvider);
    final users = ref.watch(systemUsersProvider);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Global Smart Search Logic
    final query = _searchQuery.toLowerCase();

    // 1. Filter Tasks
    final filteredTasks = tasks.where((t) {
      if (query.isEmpty) return true;
      final tMatches = t.title.toLowerCase().contains(query);
      final sMatches = subtasks
          .where((s) => s.taskId == t.id)
          .any((s) => s.title.toLowerCase().contains(query));
      return tMatches || sMatches;
    }).toList();

    // 2. Filter Subtasks
    final filteredSubtasks = subtasks.where((s) {
      if (query.isEmpty) return true;
      final sMatches = s.title.toLowerCase().contains(query);
      final tMatches = tasks.any(
        (t) => t.id == s.taskId && t.title.toLowerCase().contains(query),
      );
      return sMatches || tMatches;
    }).toList();

    // 3. Filter Projects (Phases)
    final filteredProjects = projects.where((p) {
      final pMatches =
          (p.title.toLowerCase().contains(query) ||
          p.clientName.toLowerCase().contains(query) ||
          p.clientCode.toLowerCase().contains(query));

      final anyTaskMatch = filteredTasks.any((t) => t.projectId == p.id);

      final matchesType = !p.clientType.startsWith('Profile:') && (
          _filterType == 'All' ||
          (_filterType == 'Client Course' && p.clientType != 'Internal Project') ||
          (_filterType == 'Project' && p.clientType == 'Internal Project')
      );

      final matchesTherapist =
          _filterTherapistId == null ||
          p.assignedTherapistIds.contains(_filterTherapistId);

      bool matchesStatus = true;
      if (_filterStatus == 'Active') {
        matchesStatus = p.endDate.isAfter(DateTime.now());
      } else if (_filterStatus == 'Completed') {
        matchesStatus = p.endDate.isBefore(DateTime.now());
      }

      return (pMatches || anyTaskMatch) &&
          matchesType &&
          matchesTherapist &&
          matchesStatus;
    }).toList();

    if (_isFullscreenGantt) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _isFullscreenGantt = false),
          ),
          title: Text(
            'Fullscreen Gantt',
            style: GoogleFonts.lora(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGanttHeader(theme, true),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildGanttChart(
                    context,
                    filteredProjects,
                    filteredTasks,
                    filteredSubtasks,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(theme),
        actions: const [], // Removed all previous "Add" buttons here
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32.0 : 16.0,
          vertical: 8.0,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTERS ROW
            _buildFiltersRow(theme, users),
            const SizedBox(height: 24),
            // TODAY'S SCHEDULE
            _buildTodaySchedule(theme),
            const SizedBox(height: 24),
            // GANTT
            _buildGanttHeader(theme, false),
            const SizedBox(height: 16),
            _buildGanttChart(
              context,
              filteredProjects,
              filteredTasks,
              filteredSubtasks,
            ),
            const SizedBox(height: 48),
            // KANBAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks & Workflows',
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                // Big + Sign for Add New
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        showGlassDialog(context, const EntityCreator(hideClientCourse: true)),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add New',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildKanbanGroups(
              context,
              filteredProjects,
              filteredTasks,
              filteredSubtasks,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search clients, projects, tasks...',
          hintStyle: GoogleFonts.outfit(fontSize: 13, color: theme.hintColor),
          prefixIcon: Icon(Icons.search, size: 18, color: theme.hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFiltersRow(ThemeData theme, List<AppUser> therapists) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            'Type',
            ['All', 'Client Course', 'Project'],
            _filterType,
            (v) => setState(() => _filterType = v!),
            theme,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Status',
            ['All', 'Active', 'Completed'],
            _filterStatus,
            (v) => setState(() => _filterStatus = v!),
            theme,
          ),
          const SizedBox(width: 8),
          _buildTherapistFilterChip(therapists, theme),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    List<String> options,
    String current,
    ValueChanged<String?> onChanged,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          items: options
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: GoogleFonts.outfit(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: theme.colorScheme.onSurface,
          ),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
        ),
      ),
    );
  }

  Widget _buildTherapistFilterChip(List<AppUser> therapists, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterTherapistId,
          hint: Text('Therapist', style: GoogleFonts.outfit(fontSize: 12)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All Therapists',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
            ...therapists.map(
              (u) => DropdownMenuItem<String?>(
                value: u.id,
                child: Text(
                  u.displayName,
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _filterTherapistId = v),
          icon: const Icon(Icons.person_outline, size: 18),
        ),
      ),
    );
  }

  // =====================================================
  // TODAY'S SCHEDULE
  // =====================================================
  Widget _buildTodaySchedule(ThemeData theme) {
    final schedule = ref.watch(todayScheduleProvider);
    final projects = ref.watch(projectsProvider);
    if (schedule.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Schedule",
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: schedule.map((item) {
              if (item is Session) {
                final client = projects.firstWhere(
                  (p) => p.id == item.clientId,
                  orElse: () => projects.first,
                );
                return _todayChip(
                  icon: Icons.play_circle_outline,
                  color: Colors.blue,
                  title: 'Session — ${client.clientName}',
                  subtitle: item.startTime != null
                      ? '${item.startTime!.format(context)}'
                      : 'Scheduled',
                  theme: theme,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => SessionDashboard(session: item),
                    ),
                  ),
                );
              } else if (item is ProjectTask) {
                return _todayChip(
                  icon: Icons.task_alt,
                  color: item.color,
                  title: item.title,
                  subtitle: 'Due ${DateFormat('d MMM').format(item.endDate)}',
                  theme: theme,
                  onTap: () => _openTaskEditor(item),
                );
              } else if (item is Subtask) {
                return _todayChip(
                  icon: Icons.subdirectory_arrow_right,
                  color: item.color ?? Colors.grey,
                  title: item.title,
                  subtitle: 'Due ${DateFormat('d MMM').format(item.endDate)}',
                  theme: theme,
                  onTap: () => _openSubtaskEditor(item),
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _todayChip({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 12,
                      color: theme.hintColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // GANTT HEADER
  // =====================================================
  Widget _buildGanttHeader(ThemeData theme, bool isFullscreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Therapeutic Timeline',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            _scaleChip('Day', GanttScale.day, theme),
            const SizedBox(width: 4),
            _scaleChip('Week', GanttScale.week, theme),
            const SizedBox(width: 4),
            _scaleChip('Month', GanttScale.month, theme),
            const SizedBox(width: 4),
            _scaleChip('Year', GanttScale.year, theme),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: theme.primaryColor,
              ),
              onPressed: () =>
                  setState(() => _isFullscreenGantt = !_isFullscreenGantt),
              tooltip: isFullscreen ? "Exit Fullscreen" : "Fullscreen",
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: theme.primaryColor,
                size: 22,
              ),
              onPressed: () => _navigateGantt(-1),
            ),
            InkWell(
              onTap: () => setState(() => _ganttAnchorDate = DateTime.now()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _getGanttTitle(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: theme.primaryColor,
                size: 22,
              ),
              onPressed: () => _navigateGantt(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scaleChip(String label, GanttScale scale, ThemeData theme) {
    bool active = _ganttScale == scale;
    return GestureDetector(
      onTap: () => setState(() {
        _ganttScale = scale;
        _ganttAnchorDate = DateTime.now();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : theme.hintColor,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // GANTT CHART CONTAINER
  // =====================================================
  Widget _buildGanttChart(
    BuildContext context,
    List<Project> projects,
    List<ProjectTask> tasks,
    List<Subtask> subtasks,
  ) {
    if (projects.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Reset row counter each build
    _ganttRowIndex = 0;

    return Theme(
      data: AppTheme.getTheme(isDark ? UIMode.light : UIMode.dark),
      child: Builder(
        builder: (context) {
          final invertedTheme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFFBF8F1) : const Color(0xFF161816),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: invertedTheme.dividerColor.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: invertedTheme.primaryColor.withValues(alpha: 0.03),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF8B7355).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildUniversalGantt(
                  context,
                  projects,
                  tasks,
                  subtasks,
                  constraints,
                  _ganttScale,
                );
              },
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // DAY VIEW — 7am-7pm default, stretch if needed
  // =====================================================
  Widget _buildUniversalGantt(
    BuildContext context,
    List<Project> projects,
    List<ProjectTask> tasks,
    List<Subtask> subtasks,
    BoxConstraints constraints,
    GanttScale scale,
  ) {
    final theme = Theme.of(context);
    double availableWidth = constraints.maxWidth;
    // Enhanced finite check
    if (availableWidth <= 0 || availableWidth.isInfinite || availableWidth.isNaN) {
      availableWidth = 1000;
    }
    const double labelWidth = 140;
    double timelineWidth = (availableWidth - labelWidth).clamp(400.0, double.infinity);

    int totalUnits = 1;
    double unitWidth = 0;
    DateTime startAnchor = _ganttAnchorDate;
    List<Widget> headerWidgets = [];
    double currentPos = -1;

    if (scale == GanttScale.day) {
      int startHour = 7;
      int endHour = 19;
      for (var p in projects) {
        if (_spansDay(p.startDate, p.endDate, _ganttAnchorDate)) {
          for (var t in tasks.where((t) => t.projectId == p.id)) {
            if (_spansDay(t.startDate, t.endDate, _ganttAnchorDate)) {
              if (t.startDate.day == _ganttAnchorDate.day &&
                  t.startDate.hour < startHour) startHour = t.startDate.hour;
              if (t.endDate.day == _ganttAnchorDate.day &&
                  t.endDate.hour >= endHour) endHour = t.endDate.hour + 1;
            }
          }
        }
      }
      startHour = startHour.clamp(0, 24);
      endHour = endHour.clamp(startHour + 1, 24);
      totalUnits = endHour - startHour;
      unitWidth = (timelineWidth / totalUnits).clamp(30.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month, _ganttAnchorDate.day, startHour);

      if (_isToday(_ganttAnchorDate)) {
        final now = DateTime.now();
        currentPos = (now.hour - startHour + (now.minute / 60.0)) * unitWidth;
      }

      for (int i = 0; i < totalUnits; i++) {
        int h = startHour + i;
        bool isNow = DateTime.now().hour == h && _isToday(_ganttAnchorDate);
        String label = h == 0 ? '12am' : h < 12 ? '${h}am' : h == 12 ? '12pm' : '${h - 12}pm';
        headerWidgets.add(_buildHeaderCell(label, isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.week) {
      totalUnits = 7;
      unitWidth = (timelineWidth / totalUnits).clamp(40.0, double.infinity);
      int weekday = _ganttAnchorDate.weekday;
      startAnchor = _ganttAnchorDate.subtract(Duration(days: weekday - 1));
      startAnchor = DateTime(startAnchor.year, startAnchor.month, startAnchor.day);

      final now = DateTime.now();
      if (now.isAfter(startAnchor) && now.isBefore(startAnchor.add(const Duration(days: 7)))) {
        currentPos = (now.difference(startAnchor).inMinutes / (24 * 60.0)) * unitWidth;
      }

      final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < 7; i++) {
        DateTime dayDate = startAnchor.add(Duration(days: i));
        bool isNow = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
        headerWidgets.add(_buildHeaderCell('${days[i]} ${dayDate.day}', isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.month) {
      int daysInMonth = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month + 1, 0).day;
      totalUnits = daysInMonth;
      unitWidth = (timelineWidth / totalUnits).clamp(20.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, _ganttAnchorDate.month, 1);

      final now = DateTime.now();
      if (now.year == _ganttAnchorDate.year && now.month == _ganttAnchorDate.month) {
        currentPos = (now.day - 1 + (now.hour / 24.0)) * unitWidth;
      }

      for (int i = 0; i < totalUnits; i++) {
        bool isNow = now.year == startAnchor.year && now.month == startAnchor.month && now.day == (i + 1);
        headerWidgets.add(_buildHeaderCell('${i + 1}', isNow, unitWidth, theme));
      }
    } else if (scale == GanttScale.year) {
      totalUnits = 12;
      unitWidth = (timelineWidth / totalUnits).clamp(40.0, double.infinity);
      startAnchor = DateTime(_ganttAnchorDate.year, 1, 1);

      final now = DateTime.now();
      int currentYear = DateTime.now().year;
      if (currentYear == _ganttAnchorDate.year) {
        int daysPassed = now.difference(startAnchor).inDays;
        int daysInYear = DateTime(currentYear, 12, 31).difference(startAnchor).inDays + 1;
        currentPos = (daysPassed / daysInYear) * (totalUnits * unitWidth);
      }

      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int i = 0; i < 12; i++) {
        bool isNow = now.year == startAnchor.year && now.month == (i + 1);
        headerWidgets.add(_buildHeaderCell(months[i], isNow, unitWidth, theme));
      }
    }

    double maxTotalWidth = totalUnits * unitWidth;

    double _getFraction(DateTime d) {
      if (scale == GanttScale.day) {
        return d.difference(startAnchor).inMinutes / (totalUnits * 60);
      } else if (scale == GanttScale.week || scale == GanttScale.month) {
        return d.difference(startAnchor).inMinutes / (totalUnits * 24 * 60);
      } else if (scale == GanttScale.year) {
        DateTime endYear = DateTime(startAnchor.year + 1, 1, 1);
        int totalMin = endYear.difference(startAnchor).inMinutes;
        return d.difference(startAnchor).inMinutes / totalMin;
      }
      return 0;
    }

    bool _isVisible(DateTime s, DateTime e) {
      return _getFraction(e) > 0 && _getFraction(s) < 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: labelWidth + maxTotalWidth,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(width: labelWidth),
                    ...headerWidgets,
                  ],
                ),
                const SizedBox(height: 16),
                ...projects.expand((p) {
                  List<Widget> rows = [];
                  if (!_isVisible(p.startDate, p.endDate)) return rows;

                  bool collapsed = _collapsedGanttPhases.contains(p.id);
                  rows.add(
                    _buildDayRow(
                      context,
                      p.title,
                      p.color,
                      labelWidth,
                      maxTotalWidth,
                      () => _openPhaseEditor(p),
                      height: 10,
                      isPhase: true,
                      collapsed: collapsed,
                      start: _getFraction(p.startDate),
                      end: _getFraction(p.endDate),
                      onToggle: () => setState(() {
                        if (collapsed)
                          _collapsedGanttPhases.remove(p.id);
                        else
                          _collapsedGanttPhases.add(p.id);
                      }),
                    ),
                  );

                  if (!collapsed) {
                    var pTasks = tasks.where((t) => t.projectId == p.id).toList();
                    for (var t in pTasks) {
                      if (!_isVisible(t.startDate, t.endDate)) continue;
                      bool tCollapsed = _collapsedGanttTasks.contains(t.id);
                      rows.add(
                        _buildDayRow(
                          context,
                          '  ↳ ${t.title}',
                          t.color,
                          labelWidth,
                          maxTotalWidth,
                          () => _openTaskEditor(t),
                          item: t,
                          height: 8,
                          isTask: true,
                          collapsed: tCollapsed,
                          start: _getFraction(t.startDate),
                          end: _getFraction(t.endDate),
                          onToggle: () => setState(() {
                            if (tCollapsed)
                              _collapsedGanttTasks.remove(t.id);
                            else
                              _collapsedGanttTasks.add(t.id);
                          }),
                        ),
                      );
                      if (!tCollapsed) {
                        for (var s in subtasks.where((s) => s.taskId == t.id)) {
                          if (_isVisible(s.startDate, s.endDate)) {
                            rows.add(
                              _buildDayRow(
                                context,
                                '      ↳ ${s.title}',
                                s.color ?? t.color.withValues(alpha: 0.6),
                                labelWidth,
                                maxTotalWidth,
                                () => _openSubtaskEditor(s),
                                item: s,
                                height: 6,
                                start: _getFraction(s.startDate),
                                end: _getFraction(s.endDate),
                              ),
                            );
                          }
                        }
                      }
                    }
                  }
                  return rows;
                }),
              ],
            ),
            if (currentPos >= 0 && currentPos <= maxTotalWidth)
              Positioned(
                left: labelWidth + currentPos,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: AppTheme.todayMarker(theme.brightness == Brightness.dark ? UIMode.dark : UIMode.light),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, bool isNow, double width, ThemeData theme) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isNow ? FontWeight.bold : FontWeight.w400,
              color: isNow ? theme.primaryColor : theme.hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            color: isNow
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    String title,
    Color color,
    double labelWidth,
    double timelineWidth,
    VoidCallback onTap, {
    double height = 10,
    bool isPhase = false,
    bool isTask = false,
    bool collapsed = false,
    VoidCallback? onToggle,
    double start = 0,
    double end = 1,
    dynamic item,
  }) {
    final theme = Theme.of(context);
    final uiMode = theme.brightness == Brightness.dark
        ? UIMode.dark
        : UIMode.light;
    final rowWidth = timelineWidth;
    final rowIdx = _ganttRowIndex++;

    int urgency = 0;
    if (item is ProjectTask) urgency = _getUrgency(item.endDate, item.status);
    if (item is Subtask) urgency = _getUrgency(item.endDate, item.status);

    bool extendsLeft = start < 0;
    bool extendsRight = end > 1;
    bool startsAndEndsInside = !extendsLeft && !extendsRight;

    final barHeight = startsAndEndsInside
        ? (isPhase ? AppTheme.ganttPhaseHeight * 2 : (isTask ? AppTheme.ganttTaskHeight * 2 : AppTheme.ganttSubtaskHeight * 2))
        : (isPhase ? AppTheme.ganttPhaseHeight : (isTask ? AppTheme.ganttTaskHeight : AppTheme.ganttSubtaskHeight));

    final left = (start.clamp(0.0, 1.0) * rowWidth);
    final width = ((end.clamp(0.0, 1.0) - start.clamp(0.0, 1.0)) * rowWidth)
        .clamp(8.0, rowWidth - left);

    String displayTitle = title;
    if (title.startsWith('  ↳ ')) displayTitle = title.substring(4);
    if (title.startsWith('      ↳ ')) displayTitle = title.substring(8);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppTheme.ganttRowTint(uiMode, rowIdx),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              SizedBox(
                width: labelWidth,
                child: Row(
                  children: [
                    if ((isPhase || isTask) && onToggle != null)
                      GestureDetector(
                        onTap: onToggle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            collapsed
                                ? Icons.arrow_right_rounded
                                : Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    if (!isPhase)
                      Padding(
                        padding: EdgeInsets.only(
                          left: isTask ? 8 : 20,
                          right: 6,
                        ),
                        child: Container(
                          width: isTask ? 6 : 4,
                          height: isTask ? 6 : 4,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isPhase
                              ? FontWeight.w600
                              : (isTask ? FontWeight.w500 : FontWeight.w400),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isPhase ? 0.9 : 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(height: barHeight),
                    if (isPhase)
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    Positioned(
                      left: left,
                      width: width,
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(barHeight / 2),
                          boxShadow: urgency == 2 ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ] : [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                          border: urgency > 0 ? Border.all(
                            color: urgency == 2 ? Colors.red : Colors.amber,
                            width: 1.5,
                          ) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKanbanGroups(
    BuildContext context,
    List<Project> filteredProj,
    List<ProjectTask> filteredT,
    List<Subtask> filteredS,
  ) {
    if (filteredProj.isEmpty) return [];

    final theme = Theme.of(context);

    Map<String, List<ProjectTask>> groupedByProject = {};
    for (var t in filteredT) {
      groupedByProject.putIfAbsent(t.projectId, () => []).add(t);
    }

    List<Widget> grouped = [];
    var sortedProjects = filteredProj.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    for (var p in sortedProjects) {
      List<ProjectTask> pTasks = groupedByProject[p.id] ?? [];
      bool isCollapsed = _collapsedKanbanPhases.contains(p.id);

      grouped.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: p.color,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  if (isCollapsed)
                    _collapsedKanbanPhases.remove(p.id);
                  else
                    _collapsedKanbanPhases.add(p.id);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                             Text(
                                p.clientType.replaceFirst('Profile: ', ''),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: theme.hintColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Edit button for the project
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: p.color),
                        onPressed: () => _openPhaseEditor(p),
                        tooltip: 'Edit ${p.clientType}',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 22,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: pTasks.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No tasks yet. Use "Add New" to create one.',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: theme.hintColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: pTasks.map((t) {
                            var tSubs = filteredS
                                .where((s) => s.taskId == t.id)
                                .toList();
                            tSubs.sort((a, b) => a.endDate.compareTo(b.endDate));
                            bool allDone =
                                tSubs.isNotEmpty &&
                                tSubs.every((s) => s.status == TaskStatus.done);
                            bool isTaskCollapsed = _collapsedKanbanTasks.contains(
                              t.id,
                            );
                            int taskUrgency = _getUrgency(t.endDate, t.status);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: taskUrgency == 2
                                      ? Colors.red
                                      : (taskUrgency == 1
                                            ? Colors.amber
                                            : (allDone
                                                  ? theme.dividerColor.withValues(
                                                      alpha: 0.2,
                                                    )
                                                  : Colors.transparent)),
                                  width: taskUrgency > 0 ? 4.0 : 1.0,
                                ),
                                color: allDone
                                    ? theme.scaffoldBackgroundColor
                                    : t.color.withValues(alpha: 0.25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 6,
                                      color: allDone ? theme.dividerColor : t.color,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _openTaskEditor(t),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              color: Colors.transparent,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    allDone
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    color: allDone
                                                        ? theme.dividerColor
                                                        : t.color,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      t.title,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        decoration: allDone
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                        color: allDone
                                                            ? theme.hintColor
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  if (tSubs.isNotEmpty)
                                                    GestureDetector(
                                                      onTap: () => setState(() {
                                                        if (isTaskCollapsed)
                                                          _collapsedKanbanTasks
                                                              .remove(t.id);
                                                        else
                                                          _collapsedKanbanTasks.add(
                                                            t.id,
                                                          );
                                                      }),
                                                      child: Icon(
                                                        isTaskCollapsed
                                                            ? Icons.expand_more
                                                            : Icons.expand_less,
                                                        color: theme.hintColor,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isTaskCollapsed && tSubs.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.fromLTRB(
                                                16,
                                                0,
                                                16,
                                                16,
                                              ),
                                              child: Column(
                                                children: tSubs
                                                    .map(
                                                      (s) => _buildKanbanSubtaskCard(
                                                        context,
                                                        s,
                                                        t.color,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
            ],
          ),
        ),
      );
    }

    if (grouped.isEmpty && _searchQuery.isNotEmpty) {
      grouped.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'No tasks found for "$_searchQuery".',
              style: GoogleFonts.outfit(color: theme.hintColor),
            ),
          ),
        ),
      );
    }

    return grouped;
  }


  Widget _buildKanbanSubtaskCard(
    BuildContext context,
    Subtask s,
    Color taskColor,
  ) {
    final theme = Theme.of(context);
    final isDone = s.status == TaskStatus.done;
    final chosenColor = s.color ?? taskColor;

    int subtaskUrgency = _getUrgency(s.endDate, s.status);

    return GestureDetector(
      onTap: () => _openSubtaskEditor(s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDone
              ? theme.cardTheme.color
              : chosenColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subtaskUrgency == 2
                ? Colors.red
                : (subtaskUrgency == 1 ? Colors.amber : Colors.transparent),
            width: subtaskUrgency > 0 ? 4.0 : 1.0,
          ),
          boxShadow: [],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: isDone ? theme.dividerColor : chosenColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: isDone ? theme.dividerColor : chosenColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: GoogleFonts.outfit(
                                fontWeight: isDone
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone
                                    ? theme.hintColor
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Due: ${s.endDate.day}/${s.endDate.month}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDone
                                    ? theme.hintColor
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (s.assignedUserIds.isNotEmpty)
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: chosenColor.withValues(alpha: 0.5),
                          child: const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      else
                        Tooltip(
                          message: 'No user assigned — please assign a team member',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
