import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/project_module.dart';
import '../../models/project_module.dart';
import '../../providers/app_state.dart';
import '../multi_select_dropdown.dart';

class EntityCreator extends ConsumerStatefulWidget {
  final String? initialEntityType;
  final String? initialParentPhaseId;
  final String? initialParentTaskId;

  const EntityCreator({
    Key? key,
    this.initialEntityType,
    this.initialParentPhaseId,
    this.initialParentTaskId,
  }) : super(key: key);

  @override
  _EntityCreatorState createState() => _EntityCreatorState();
}

class _EntityCreatorState extends ConsumerState<EntityCreator> {
  late String _entityType;
  String? _selectedClientId;
  List<String> _assignedTherapistIds = [];
  String? _parentPhaseId;
  String? _parentTaskId;
  String _selectedClientType = 'Private';

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Color _color = const Color(0xFF38BDF8);

  @override
  void initState() {
    super.initState();
    _entityType = widget.initialEntityType ?? 'Task';
    _parentPhaseId = widget.initialParentPhaseId;
    _parentTaskId = widget.initialParentTaskId;

    // Default color if parent task is known
    _updateDefaultColorAndDates();
  }

  void _updateDefaultColorAndDates() {
    if (_entityType == 'Subtask' && _parentTaskId != null) {
      final tasks = ref.read(tasksProvider);
      final pTask = tasks.where((t) => t.id == _parentTaskId).firstOrNull;
      if (pTask != null) {
        _color = pTask.color;
        // Adjust dates to parent bounds if current ones are outside
        if (_startDate.isBefore(pTask.startDate)) _startDate = pTask.startDate;
        if (_endDate.isAfter(pTask.endDate)) _endDate = pTask.endDate;
      }
    }
  }

  final List<Color> _palette = [
    const Color(0xFF38BDF8),
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  Future<void> _pickDate(bool isStart) async {
    DateTime first = DateTime(2020);
    DateTime last = DateTime(2035);

    // Enforce bounds if subtask
    if (_entityType == 'Subtask' && _parentTaskId != null) {
      final pTask = ref
          .read(tasksProvider)
          .where((t) => t.id == _parentTaskId)
          .firstOrNull;
      if (pTask != null) {
        first = pTask.startDate;
        last = pTask.endDate;
      }
    }

    final pd = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate).isBefore(first)
          ? first
          : ((isStart ? _startDate : _endDate).isAfter(last)
                ? last
                : (isStart ? _startDate : _endDate)),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) {
        // Option to grey out unavailable dates is implicit in firstDate/lastDate
        return true;
      },
    );
    if (pd != null)
      setState(() {
        if (isStart)
          _startDate = pd;
        else
          _endDate = pd;
      });
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (t != null)
      setState(() {
        if (isStart)
          _startTime = t;
        else
          _endTime = t;
      });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty) return;
    final isClientCourse = _entityType == 'Client Course';
    final isProject = _entityType == 'Project';
    final isSession = _entityType == 'Session';
    final isTask = _entityType == 'Task';
    final isSubtask = _entityType == 'Subtask';

    try {
      if (isClientCourse || isProject) {
        if (isClientCourse && _selectedClientId == null) return;
        final template = isClientCourse
            ? ref
                .read(projectsProvider)
                .firstWhere((p) => p.clientId == _selectedClientId)
            : null;

        final newProject = Project(
          title: _titleCtrl.text,
          clientId: template?.clientId ?? 'INTERNAL',
          firstName: template?.firstName ?? '',
          lastName: template?.lastName ?? '',
          clientCode:
              template?.clientCode ?? 'INT-${DateTime.now().millisecond}',
          clientType: isClientCourse ? _selectedClientType : 'Internal Project',
          assignedTherapistIds: _assignedTherapistIds,
          notes: _descCtrl.text,
          startDate: _startDate,
          endDate: _endDate,
          color: _color,
        );

        await ref.read(projectsProvider.notifier).addProject(newProject);

        if (isClientCourse) {
          await ref.read(tasksProvider.notifier).addTask(
                ProjectTask(
                  projectId: newProject.id,
                  title: 'Therapy Sessions',
                  description:
                      'Automatically managed task for therapy sessions.',
                  startDate: _startDate,
                  endDate: _endDate,
                  color: Colors.blueAccent,
                ),
              );
        }
      } else if (isTask) {
        if (_parentPhaseId == null) return;
        await ref.read(tasksProvider.notifier).addTask(
              ProjectTask(
                projectId: _parentPhaseId!,
                title: _titleCtrl.text,
                description: _descCtrl.text,
                startDate: _startDate,
                endDate: _endDate,
                color: _color,
                assignedUserIds: _assignedTherapistIds.isEmpty
                    ? ['unassigned']
                    : _assignedTherapistIds,
              ),
            );
      } else if (isSession) {
        if (_parentPhaseId == null) return;
        final tasks = ref.read(tasksProvider);
        ProjectTask therapyTask = tasks.firstWhere(
          (t) => t.projectId == _parentPhaseId && t.title == 'Therapy Sessions',
          orElse: () => ProjectTask(
            projectId: _parentPhaseId!,
            title: 'Therapy Sessions',
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 365)),
            color: Colors.blueAccent,
          ),
        );

        // Ensure task exists in DB
        if (!tasks.any((t) => t.id == therapyTask.id)) {
          await ref.read(tasksProvider.notifier).addTask(therapyTask);
        }

        final combinedDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _startTime?.hour ?? 9,
          _startTime?.minute ?? 0,
        );

        // Add as subtask (Kanban/Gantt only shows tasks/subtasks)
        await ref.read(subtasksProvider.notifier).addSubtask(
              Subtask(
                taskId: therapyTask.id,
                title: _titleCtrl.text,
                description: _descCtrl.text,
                startDate: combinedDate,
                endDate: combinedDate.add(const Duration(hours: 1)),
                color: _color,
              ),
            );

        // Add actual session
        await ref.read(sessionsProvider.notifier).addSession(
              Session(
                clientId: _parentPhaseId!,
                therapistIds: _assignedTherapistIds,
                date: combinedDate,
                therapistNotes: _descCtrl.text,
                durationMinutes: 60,
                type: SessionType.individual,
                status: SessionStatus.scheduled,
                generalDiscussion: '',
                generalMood: '',
              ),
            );
      } else if (isSubtask) {
        if (_parentTaskId == null) return;
        await ref.read(subtasksProvider.notifier).addSubtask(
              Subtask(
                taskId: _parentTaskId!,
                title: _titleCtrl.text,
                description: _descCtrl.text,
                startDate: _startDate,
                endDate: _endDate,
                color: _color,
                assignedUserIds: _assignedTherapistIds.isEmpty
                    ? ['unassigned']
                    : _assignedTherapistIds,
              ),
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_entityType added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding $_entityType: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);

    final isTopLevel =
        _entityType == 'Client Course' || _entityType == 'Project';
    final isTask = _entityType == 'Task';
    final isSubtask = _entityType == 'Subtask';

    // Build filteredTasks: only tasks from selected parent phase
    final filteredTasks = isSubtask && _parentPhaseId != null
        ? tasks.where((t) => t.projectId == _parentPhaseId).toList()
        : tasks;

    bool canSave =
        _titleCtrl.text.isNotEmpty &&
        (isTopLevel ||
            (isTask && _parentPhaseId != null) ||
            (isSubtask && _parentTaskId != null));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with type selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add New',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _entityType,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.primaryColor,
                ),
                items:
                    ['Client Course', 'Project', 'Task', 'Subtask', 'Session']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      _entityType = v;
                      _parentPhaseId = null;
                      _parentTaskId = null;
                    });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Client (only for Client Course)
                  if (_entityType == 'Client Course') ...[
                    DropdownButtonFormField<String>(
                      decoration: _dec('Client Type *', theme),
                      value: _selectedClientType,
                      items: ref.watch(clientTypesProvider)
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedClientType = v!),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Title *', theme),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: _dec('Description', theme),
                  ),
                  const SizedBox(height: 12),

                  // Parent selection for Task / Session
                  if (isTask || _entityType == 'Session')
                    DropdownButtonFormField<String>(
                      decoration: _dec(
                        _entityType == 'Session'
                            ? 'Attributed Client Course *'
                            : 'Parent Client Course / Project *',
                        theme,
                      ),
                      value: _parentPhaseId,
                      items: projects
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.title),
                            ),
                          )
                          .toList(),
                      onChanged: (widget.initialParentPhaseId != null)
                          ? null
                          : (v) => setState(() => _parentPhaseId = v),
                    ),

                  if (_entityType == 'Session') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Will be filed under "Therapy Sessions" automatically.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Parent selection for Subtask
                  if (isSubtask) ...[
                    DropdownButtonFormField<String>(
                      decoration: _dec('Client Course / Project *', theme),
                      value: _parentPhaseId,
                      items: projects
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.title),
                            ),
                          )
                          .toList(),
                      onChanged: (widget.initialParentPhaseId != null)
                          ? null
                          : (v) => setState(() {
                              _parentPhaseId = v;
                              _parentTaskId = null;
                            }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: _dec('Parent Task *', theme),
                      value: _parentTaskId,
                      items: tasks
                          .where((t) => t.projectId == _parentPhaseId)
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.title),
                            ),
                          )
                          .toList(),
                      onChanged: (widget.initialParentTaskId != null)
                          ? null
                          : (v) => setState(() => _parentTaskId = v),
                    ),
                  ],
                  if (isTask || isSubtask || _entityType == 'Session')
                    const SizedBox(height: 12),

                  // Assign Therapist
                  MultiSelectDropdown(
                    title: 'Assign Therapist / Admin',
                    users: ref.watch(systemUsersProvider),
                    selectedIds: _assignedTherapistIds,
                    onChanged: (v) => setState(() => _assignedTherapistIds = v),
                  ),
                  const SizedBox(height: 12),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: _dateTile(
                          'Start',
                          _startDate,
                          () => _pickDate(true),
                          theme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dateTile(
                          'End',
                          _endDate,
                          () => _pickDate(false),
                          theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Optional time (for tasks/subtasks)
                  if (isTask || isSubtask) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Time (Optional)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                        if (isSubtask && _parentTaskId != null)
                          Builder(
                            builder: (ctx) {
                              final pTask = ref
                                  .watch(tasksProvider)
                                  .where((t) => t.id == _parentTaskId)
                                  .firstOrNull;
                              if (pTask == null) return const SizedBox();
                              return Text(
                                'Bound: ${DateFormat('Hm').format(pTask.startDate)} - ${DateFormat('Hm').format(pTask.endDate)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _startTime?.format(context) ?? 'Start time',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: _startTime != null
                                          ? theme.colorScheme.onSurface
                                          : theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _endTime?.format(context) ?? 'End time',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: _endTime != null
                                          ? theme.colorScheme.onSurface
                                          : theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Color picker
                  Text(
                    'Theme Colour',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _palette
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: _color == c
                                    ? Border.all(
                                        color: theme.colorScheme.onSurface,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: _color == c
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Text('Add $_entityType'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, ThemeData theme) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _dateTile(
    String label,
    DateTime date,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: theme.hintColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(date),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
