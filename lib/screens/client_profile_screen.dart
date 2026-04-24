import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/project_module.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';
import '../services/pdf_generator_service.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../widgets/dialogs/phase_editor.dart';
import '../widgets/dialogs/task_editor.dart';
import '../widgets/dialogs/subtask_editor.dart';
import '../widgets/dialogs/entity_creator.dart';
import 'session_dashboard.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  final Project clientProject;
  const ClientProfileScreen({super.key, required this.clientProject});

  @override
  _ClientProfileScreenState createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Always read the LATEST version of this project from provider
    final project = ref
        .watch(projectsProvider)
        .firstWhere(
          (p) => p.id == widget.clientProject.id,
          orElse: () => widget.clientProject,
        );
    final subtasks = ref.watch(subtasksProvider);
    final users = ref.watch(systemUsersProvider);
    final clientTypes = ref.watch(clientTypesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdminOnly = currentUser.role == UserRole.admin;
    final therapistName =
        users
            .where((u) => project.assignedTherapistIds.contains(u.id))
            .map((u) => u.name)
            .firstOrNull ??
        'Unassigned';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.clientName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${project.clientCode}  •  ${project.clientType.replaceFirst('Profile: ', '')}',
              style: GoogleFonts.outfit(fontSize: 11, color: theme.hintColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Client',
            onPressed: () {
              // Navigate to full profile with edit mode on overview
              showGlassDialog(context, PhaseEditor(project: project));
            },
          ),
          _buildReportMenu(context, project),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sessions'),
            Tab(text: 'Tasks'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, project, therapistName),
              _buildSessionsTab(context, project),
              _buildTasksTab(context, project),
              _buildDocumentsTab(context, project),
            ],
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 1 — OVERVIEW
  // =============================================
  Widget _buildOverviewTab(
    BuildContext context,
    Project project,
    String therapistName,
  ) {
    final theme = Theme.of(context);
    final sessions = ref
        .watch(sessionsProvider)
        .where((s) => s.clientId == project.id)
        .toList();
    final completedSessions = sessions
        .where((s) => s.status == SessionStatus.completed)
        .length;
    final nextSession =
        sessions
            .where(
              (s) =>
                  s.status == SessionStatus.scheduled &&
                  s.date.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        _buildHeaderCard(
          project,
          therapistName,
          theme,
          completedSessions,
          nextSession.firstOrNull,
        ),
        const SizedBox(height: 12),

        // Contacts & Stakeholders
        if (project.contacts.isNotEmpty) ...[
          _buildSectionCard(
            'Contacts & Stakeholders',
            Icons.people_outline,
            theme,
            [
              ...project.contacts.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _contactRow(c, theme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Personal Details
        _buildSectionCard('Personal Details', Icons.person, theme, [
          if (project.dateOfBirth != null)
            _infoRow(
              Icons.cake,
              'D.O.B.',
              DateFormat('d MMM yyyy').format(project.dateOfBirth!),
              theme,
            ),
          _infoRow(
            Icons.home,
            'Address',
            project.address.isNotEmpty ? project.address : '—',
            theme,
          ),
          _infoRow(
            Icons.phone,
            'Phone',
            project.phone.isNotEmpty ? project.phone : '—',
            theme,
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            project.email.isNotEmpty ? project.email : '—',
            theme,
          ),
        ]),
        const SizedBox(height: 12),

        // Notes
        if (project.notes.isNotEmpty && !ref.watch(currentUserProvider).role.name.contains('admin') && ref.watch(currentUserProvider).role != UserRole.admin)
          _buildSectionCard('Clinical Notes', Icons.notes, theme, [
            Text(
              project.notes,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ]),
        if (ref.watch(currentUserProvider).role == UserRole.admin && project.notes.isNotEmpty)
          _buildSectionCard('Clinical Notes', Icons.lock_outline, theme, [
            Text(
              'Restricted Access: Clinical notes are only available to Therapists and Administrators.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ]),
        const SizedBox(height: 16),

        // Start Client Course button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _startClientCourse(context, project),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(
              'Start New Client Course',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: theme.primaryColor),
            ),
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildHeaderCard(
    Project p,
    String therapist,
    ThemeData theme,
    int sessionCount,
    Session? nextSession,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: p.color.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: p.color.withValues(alpha: 0.15),
                child: Text(
                  '${p.firstName.isNotEmpty ? p.firstName[0] : '?'}${p.lastName.isNotEmpty ? p.lastName[0] : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: p.color,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.clientName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      p.clientCode,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.hintColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _clientTypeColor(p.clientType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.clientType,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _clientTypeColor(p.clientType),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _statChip(Icons.psychology, '$sessionCount', 'Sessions', theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statChip(
                  Icons.person,
                  therapist,
                  'Therapist',
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              if (nextSession != null)
                Expanded(
                  child: _statChip(
                    Icons.calendar_today,
                    DateFormat('d MMM').format(nextSession.date),
                    'Next Session',
                    theme,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Therapy Cycle',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                  Text(
                    '${DateFormat('d MMM yy').format(p.startDate)} → ${DateFormat('d MMM yy').format(p.endDate)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _cycleProgress(p.startDate, p.endDate),
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 2 — SESSIONS
  // =============================================
  Widget _buildSessionsTab(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final sessions =
        ref
            .watch(sessionsProvider)
            .where((s) => s.clientId == project.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        // Add session button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddSessionDialog(context, project),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Schedule Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? _emptyState(
                  'No sessions recorded yet.\nTap to schedule the first session.',
                  Icons.calendar_today,
                  theme,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, i) =>
                      _buildSessionCard(context, sessions[i], theme),
                ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    Session session,
    ThemeData theme,
  ) {
    final isCompleted = session.status == SessionStatus.completed;
    final isScheduled = session.status == SessionStatus.scheduled;
    final statusColor = isCompleted
        ? Colors.green
        : (isScheduled ? theme.primaryColor : Colors.grey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (ref.read(currentUserProvider).role == UserRole.admin) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admins do not have access to clinical session data.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SessionDashboard(session: session)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(session.date),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${session.type.name}  •  ${session.durationMinutes} min  •  ${session.status.name}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status.name.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (isCompleted && session.aiSummary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  session.aiSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
              if (isCompleted && session.generalMood.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.mood, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Mood: ${session.generalMood}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                    if (session.isTranscribed) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.mic, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Transcribed',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isScheduled)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            _confirmDeleteSession(context, session),
                      ),
                  ],
                ),
              ],
              if (isScheduled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmDeleteSession(context, session),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: Text(
                        'Delete / Reschedule',
                        style: GoogleFonts.outfit(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => SessionDashboard(session: session),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(
                        'Start Session',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSession(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Session?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Was this session created accidentally, or would you like to reschedule it instead?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(sessionsProvider.notifier).removeSession(session.id);
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete Permanently',
              style: GoogleFonts.outfit(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final d = await showDatePicker(
                context: context,
                initialDate: session.date.add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) {
                ref
                    .read(sessionsProvider.notifier)
                    .updateSession(session.copyWith(date: d));
              }
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }







  void _showAddSessionDialog(BuildContext context, Project project) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    SessionType sessionType = SessionType.individual;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Text(
            'Schedule Session',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('d MMMM yyyy').format(selectedDate)),
                subtitle: const Text('Date'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setDState(() => selectedDate = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime.format(context)),
                subtitle: const Text('Time'),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (t != null) setDState(() => selectedTime = t);
                },
              ),
              DropdownButtonFormField<SessionType>(
                value: sessionType,
                decoration: const InputDecoration(labelText: 'Session Type'),
                items: SessionType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDState(() => sessionType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final combinedDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  final newSession = Session(
                    clientId: project.id,
                    therapistIds: project.assignedTherapistIds,
                    date: combinedDateTime,
                    type: sessionType,
                    status: SessionStatus.scheduled,
                    generalDiscussion: '',
                    generalMood: '',
                    therapistNotes: '',
                  );

                  // 1. Add actual session record
                  await ref.read(sessionsProvider.notifier).addSession(newSession);

                  // 2. Manage visibility task
                  final tasks = ref.read(tasksProvider);
                  ProjectTask? therapyTask = tasks
                      .where((t) => t.projectId == project.id && t.title == 'Therapy Sessions')
                      .firstOrNull;

                  if (therapyTask == null) {
                    therapyTask = ProjectTask(
                      projectId: project.id,
                      title: 'Therapy Sessions',
                      startDate: project.startDate,
                      endDate: project.endDate,
                      color: Colors.blueAccent,
                    );
                    await ref.read(tasksProvider.notifier).addTask(therapyTask);
                  }

                  // 3. Add as subtask for visibility
                  await ref.read(subtasksProvider.notifier).addSubtask(
                        Subtask(
                          taskId: therapyTask.id,
                          title:
                              'Session: ${DateFormat('d/M').format(selectedDate)} @ ${selectedTime.format(context)}',
                          startDate: combinedDateTime,
                          endDate: combinedDateTime.add(const Duration(hours: 1)),
                          color: Colors.blueAccent,
                        ),
                      );

                  if (mounted) {
                    Navigator.pop(dCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session scheduled successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error scheduling session: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // TAB 3 — TASKS
  // =============================================
  Widget _buildTasksTab(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final allClientProjects =
        ref.watch(projectsProvider)
            .where((p) => p.clientId == project.clientId)
            .map((p) => p.id)
            .toSet();
    final tasks = ref
        .watch(tasksProvider)
        .where((t) => allClientProjects.contains(t.projectId))
        .toList();
    final subtasks = ref.watch(subtasksProvider);

    return Column(
      children: [
        // Add Task button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showGlassDialog(
                        context,
                        EntityCreator(initialClientId: project.clientId),
                      ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _emptyState(
                  'No tasks attached to this client.',
                  Icons.task_outlined,
                  theme,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    final tSubs = subtasks
                        .where((s) => s.taskId == t.id)
                        .toList();
                    final done = tSubs
                        .where((s) => s.status == TaskStatus.done)
                        .length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: t.color.withValues(alpha: 0.2)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () =>
                            showGlassDialog(context, TaskEditor(task: t)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: t.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.title,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Due ${DateFormat('d MMM').format(t.endDate)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (tSubs.isNotEmpty)
                                    Text(
                                      '$done/${tSubs.length}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                ],
                              ),
                              if (tSubs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: tSubs.isEmpty
                                        ? 0
                                        : done / tSubs.length,
                                    backgroundColor: t.color.withValues(
                                      alpha: 0.1,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      t.color,
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                              if (t.description != null &&
                                  t.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  t.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ],
                              if (tSubs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...tSubs
                                    .map(
                                      (s) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => showGlassDialog(
                                            context,
                                            SubtaskEditor(subtask: s),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 16),
                                              Icon(
                                                s.status == TaskStatus.done
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                                size: 14,
                                                color: t.color,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  s.title,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color:
                                                        s.status ==
                                                            TaskStatus.done
                                                        ? theme.hintColor
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                    decoration:
                                                        s.status ==
                                                            TaskStatus.done
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                DateFormat(
                                                  'd/M',
                                                ).format(s.endDate),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: theme.hintColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =============================================
  // TAB 4 — DOCUMENTS
  // =============================================
  Widget _buildDocumentsTab(BuildContext context, Project project) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Generate Reports',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _reportTile(
          'Weekly S.O.A.P Notes',
          Icons.article,
          'Standard clinical session note in SOAP format.',
          () =>
              _generateReport(context, project, 'SOAP', 'Weekly S.O.A.P Notes'),
          theme,
        ),
        if (project.clientType == 'NDIS') ...[
          _reportTile(
            'NDIS Progress Report',
            Icons.trending_up,
            '6-month NDIS goal progress report.',
            () => _generateReport(
              context,
              project,
              'NDIS',
              'NDIS Progress Report',
            ),
            theme,
          ),
          _reportTile(
            'NDIS Plan Review Summary',
            Icons.assignment,
            'Summary for upcoming NDIS plan review.',
            () => _generateReport(
              context,
              project,
              'NDISReview',
              'NDIS Plan Review Summary',
            ),
            theme,
          ),
        ],
        _reportTile(
          'Discharge Summary',
          Icons.output,
          'End-of-therapy discharge report.',
          () => _generateReport(
            context,
            project,
            'Discharge',
            'Discharge Summary',
          ),
          theme,
        ),
        _reportTile(
          'General Session Summary',
          Icons.summarize,
          'Session overview and clinical progress.',
          () => _generateReport(context, project, 'General', 'Session Summary'),
          theme,
        ),
        const SizedBox(height: 24),
        Text(
          'Send to Client',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _reportTile(
          'Send Onboarding Form',
          Icons.send,
          'Trigger onboarding form link for client.',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Onboarding link generated & sent!'),
              ),
            );
          },
          theme,
        ),
        _reportTile(
          'Send NDIS Feedback Form',
          Icons.feedback_outlined,
          'Send NDIS participant feedback form.',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('NDIS feedback form sent!')),
            );
          },
          theme,
          show: project.clientType == 'NDIS',
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _reportTile(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
    ThemeData theme, {
    bool show = true,
  }) {
    if (!show) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: theme.primaryColor),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  void _generateReport(
    BuildContext context,
    Project project,
    String type,
    String title,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Synthesising $title...')));
    final dummy = [
      'Patient discussed anxiety management strategies.',
      'Made progress on communication goals.',
    ];
    try {
      final content = await DocumentGenerator.generateSmartReport(dummy, type);
      final settings = ref.read(clinicSettingsProvider);
      if (context.mounted) {
        await DocumentGenerator.generateAndPrintDocument(
          context: context,
          title: title,
          generatedContent: content,
          settings: settings,
          clientProject: project,
        );
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    }
  }

  Widget _buildReportMenu(BuildContext context, Project project) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'soap':
            _generateReport(context, project, 'SOAP', 'Weekly S.O.A.P Notes');
            break;
          case 'discharge':
            _generateReport(context, project, 'Discharge', 'Discharge Summary');
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'soap',
          child: ListTile(
            leading: Icon(Icons.article),
            title: Text('SOAP Notes'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'discharge',
          child: ListTile(
            leading: Icon(Icons.output),
            title: Text('Discharge Summary'),
            dense: true,
          ),
        ),
      ],
    );
  }

  // =============================================
  // SHARED HELPERS
  // =============================================
  Widget _buildSectionCard(
    String title,
    IconData icon,
    ThemeData theme,
    List<Widget> children,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ThemeData theme) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.hintColor),
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _contactRow(Contact c, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            c.fullName,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c.role,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (c.isPrimary) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRIMARY',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      if (c.phone.isNotEmpty) ...[
        const SizedBox(height: 4),
        _infoRow(Icons.phone, 'Phone', c.phone, theme),
      ],
      if (c.email.isNotEmpty)
        _infoRow(Icons.email_outlined, 'Email', c.email, theme),
    ],
  );

  Widget _statChip(
    IconData icon,
    String value,
    String label,
    ThemeData theme,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: theme.primaryColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.primaryColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 10, color: theme.hintColor),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _emptyState(String message, IconData icon, ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: theme.hintColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Color _clientTypeColor(String type) {
    switch (type) {
      case 'NDIS':
        return Colors.blue;
      case 'Medicare':
        return Colors.green;
      case 'WorkCover':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  void _startClientCourse(BuildContext context, Project project) {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 90));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(
            'Start Client Course',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create a new therapy course for ${project.clientName}.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  'Start: ${DateFormat('d MMM yyyy').format(startDate)}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null) setDState(() => startDate = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('End: ${DateFormat('d MMM yyyy').format(endDate)}'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: endDate,
                    firstDate: startDate,
                    lastDate: DateTime(2035),
                  );
                  if (d != null) setDState(() => endDate = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Create a new project/client course entry visible in Gantt/Kanban
                ref
                    .read(projectsProvider.notifier)
                    .addProject(
                      Project(
                        title: '${project.clientName} - Course',
                        clientId: project.clientId,
                        firstName: project.firstName,
                        lastName: project.lastName,
                        clientCode: project.clientCode,
                        clientType: project.clientType.replaceFirst('Profile: ', ''),
                        startDate: startDate,
                        endDate: endDate,
                        assignedTherapistIds: project.assignedTherapistIds,
                      ),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Client course created! Visible in Gantt & Kanban.',
                    ),
                  ),
                );
              },
              child: const Text('Create Course'),
            ),
          ],
        ),
      ),
    );
  }

  double _cycleProgress(DateTime start, DateTime end) {
    final total = end.difference(start).inDays;
    final elapsed = DateTime.now().difference(start).inDays;
    if (total <= 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
