import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/project_module.dart';
import '../../models/clinic_settings.dart';
import '../../providers/app_state.dart';
import '../../theme/organic_palette.dart';
import '../multi_select_dropdown.dart';

class EntityCreator extends ConsumerStatefulWidget {
  final String? initialEntityType;
  final String? initialParentPhaseId;
  final String? initialParentTaskId;
  final String? initialClientId;

  const EntityCreator({
    super.key,
    this.initialEntityType,
    this.initialParentPhaseId,
    this.initialParentTaskId,
    this.initialClientId,
    this.hideClientCourse = false,
  });

  final bool hideClientCourse;

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entityType = widget.initialEntityType ?? 'Task';
    _parentPhaseId = widget.initialParentPhaseId;
    _parentTaskId = widget.initialParentTaskId;

    // Automatic self-assignment for therapists
    final currentUser = ref.read(currentUserProvider);
    if (currentUser.role == UserRole.therapist) {
      _assignedTherapistIds = [currentUser.id];
    }

    // Default color if parent task is known
    _updateDefaultColorAndDates();
  }

  void _updateDefaultColorAndDates() {
    if (_entityType == 'Subtask' && _parentTaskId != null) {
      final tasks = ref.read(tasksProvider);
      final pTask = tasks.where((t) => t.id == _parentTaskId).firstOrNull;
      if (pTask != null) {
        _color = pTask.color;
      }
    }
  }

  final List<Color> _palette = OrganicPalette.colors;

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text('Got it'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final pd = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pd != null) {
      setState(() {
        if (isStart) {
          _startDate = pd;
        } else {
          _endDate = pd;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (t != null) {
      setState(() {
        if (isStart) {
          _startTime = t;
        } else {
          _endTime = t;
        }
      });
    }
  }

  /// Checks if child dates exceed parent bounds and shows a confirmation dialog.
  /// Returns true if the save should proceed (dates are fine or user confirmed auto-extend).
  Future<bool> _validateAndExtendParentDates() async {
    final isTask = _entityType == 'Task';
    final isSubtask = _entityType == 'Subtask';
    if (!isTask && !isSubtask) return true;

    final projects = ref.read(projectsProvider);
    final tasks = ref.read(tasksProvider);

    if (isTask && _parentPhaseId != null) {
      // Task → check against parent project
      final parentProject = projects.where((p) => p.id == _parentPhaseId).firstOrNull;
      if (parentProject == null) return true;

      final startBefore = _startDate.isBefore(parentProject.startDate);
      final endAfter = _endDate.isAfter(parentProject.endDate);

      if (startBefore || endAfter) {
        final confirmed = await _showDateBoundaryDialog(
          parentType: 'project',
          parentName: parentProject.title,
          parentStart: parentProject.startDate,
          parentEnd: parentProject.endDate,
          childStart: _startDate,
          childEnd: _endDate,
        );
        if (!confirmed) return false;

        // Auto-extend project dates
        final newStart = startBefore ? _startDate : parentProject.startDate;
        final newEnd = endAfter ? _endDate : parentProject.endDate;
        ref.read(projectsProvider.notifier).updateProject(
          parentProject.copyWith(startDate: newStart, endDate: newEnd),
        );
      }
    } else if (isSubtask && _parentTaskId != null) {
      // Subtask → check against parent task, then grandparent project
      final parentTask = tasks.where((t) => t.id == _parentTaskId).firstOrNull;
      if (parentTask == null) return true;

      final startBefore = _startDate.isBefore(parentTask.startDate);
      final endAfter = _endDate.isAfter(parentTask.endDate);

      if (startBefore || endAfter) {
        final confirmed = await _showDateBoundaryDialog(
          parentType: 'task',
          parentName: parentTask.title,
          parentStart: parentTask.startDate,
          parentEnd: parentTask.endDate,
          childStart: _startDate,
          childEnd: _endDate,
        );
        if (!confirmed) return false;

        // Auto-extend task dates
        final newTaskStart = startBefore ? _startDate : parentTask.startDate;
        final newTaskEnd = endAfter ? _endDate : parentTask.endDate;
        ref.read(tasksProvider.notifier).updateTask(
          parentTask.copyWith(startDate: newTaskStart, endDate: newTaskEnd),
        );

        // Now check if the extended task dates exceed the grandparent project
        final grandparentProject = projects.where((p) => p.id == parentTask.projectId).firstOrNull;
        if (grandparentProject != null) {
          final gpStartBefore = newTaskStart.isBefore(grandparentProject.startDate);
          final gpEndAfter = newTaskEnd.isAfter(grandparentProject.endDate);
          if (gpStartBefore || gpEndAfter) {
            ref.read(projectsProvider.notifier).updateProject(
              grandparentProject.copyWith(
                startDate: gpStartBefore ? newTaskStart : grandparentProject.startDate,
                endDate: gpEndAfter ? newTaskEnd : grandparentProject.endDate,
              ),
            );
          }
        }
      }
    }
    return true;
  }

  Future<bool> _showDateBoundaryDialog({
    required String parentType,
    required String parentName,
    required DateTime parentStart,
    required DateTime parentEnd,
    required DateTime childStart,
    required DateTime childEnd,
  }) async {
    final df = DateFormat('d MMM yyyy');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Dates exceed $parentType',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The dates you selected fall outside the parent $parentType "$parentName":',
              style: GoogleFonts.outfit(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parent $parentType dates:',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${df.format(parentStart)}  →  ${df.format(parentEnd)}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your selected dates:',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${df.format(childStart)}  →  ${df.format(childEnd)}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Proceeding will automatically extend the $parentType dates to accommodate this item.',
              style: GoogleFonts.outfit(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Extend & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final isClientCourse = _entityType == 'Client Course';
    final isProject = _entityType == 'Project';
    final isSession = _entityType == 'Session';
    final isTask = _entityType == 'Task';
    final isSubtask = _entityType == 'Subtask';

    // Validate date boundaries for tasks/subtasks
    if (isTask || isSubtask) {
      final proceed = await _validateAndExtendParentDates();
      if (!proceed) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    }

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
                assignedUserIds: _assignedTherapistIds,
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
                assignedUserIds: _assignedTherapistIds,
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
        !_isSaving &&
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
                    (widget.hideClientCourse
                            ? ['Project', 'Task', 'Subtask']
                            : ['Client Course', 'Project', 'Task', 'Subtask', 'Session'])
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
                          .where((p) {
                            // Filter: Exclude administrative "Profile" projects for clinical tasks.
                            // If on a specific client profile, only show their courses.
                            if (p.clientType.startsWith('Profile:')) return false;
                            if (widget.initialClientId != null &&
                                p.clientId != widget.initialClientId) return false;
                            return true;
                          })
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
                          .where((p) {
                            if (p.clientType.startsWith('Profile:')) return false;
                            if (widget.initialClientId != null &&
                                p.clientId != widget.initialClientId) return false;
                            return true;
                          })
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

                  // Assign Therapist (hidden for therapists, only admins can reassign)
                  if (ref.read(currentUserProvider).role != UserRole.therapist) ...[
                    MultiSelectDropdown(
                      title: 'Assign Therapist / Admin',
                      users: ref.watch(systemUsersProvider),
                      selectedIds: _assignedTherapistIds,
                      onChanged: (v) => setState(() => _assignedTherapistIds = v),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                    runSpacing: 8,
                    children: [
                      ..._palette.map(
                            (c) => GestureDetector(
                              onTap: () => setState(() => _color = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: _color.value == c.value
                                      ? Border.all(
                                          color: theme.colorScheme.onSurface,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: _color.value == c.value
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                    ],
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
                  child: _isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Add $_entityType'),
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
