import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/project_module.dart';
import '../../models/clinic_settings.dart';
import '../../providers/app_state.dart';
import 'subtask_editor.dart';
import 'entity_creator.dart';
import 'glass_dialog.dart';
import '../multi_select_dropdown.dart';

class TaskEditor extends ConsumerStatefulWidget {
  final ProjectTask task;
  const TaskEditor({Key? key, required this.task}) : super(key: key);

  @override
  _TaskEditorState createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late Color _color;
  List<String> _assignedUserIds = [];

  final List<Color> _palette = [
    const Color(0xFF38BDF8),
    const Color(0xFF00B4D8),
    const Color(0xFF10B981),
    const Color(0xFFD4AF37),
    const Color(0xFFF4A261),
    const Color(0xFFE29578),
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;
    _color = widget.task.color;
    _assignedUserIds = List.from(widget.task.assignedUserIds);
  }

  Future<void> _pickDate(bool isStart) async {
    final cur = isStart ? _startDate : _endDate;
    final pd = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pd != null) {
      final pt = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(cur),
      );
      if (pt != null) {
        final newDate = DateTime(pd.year, pd.month, pd.day, pt.hour, pt.minute);
        setState(() {
          if (isStart)
            _startDate = newDate;
          else
            _endDate = newDate;
        });
      }
    }
  }

  void _save() {
    final upd = widget.task.copyWith(
      title: _titleCtrl.text,
      description: _descCtrl.text,
      startDate: _startDate,
      endDate: _endDate,
      color: _color,
      assignedUserIds: _assignedUserIds.isEmpty ? ['unassigned'] : _assignedUserIds,
    );
    ref.read(tasksProvider.notifier).updateTask(upd);
    setState(() => _isEditing = false);
  }

  void _confirmDelete(BuildContext context) {
    final subtasks = ref
        .read(subtasksProvider)
        .where((s) => s.taskId == widget.task.id)
        .toList();
    final hasIncomplete = subtasks.any((s) => s.status != TaskStatus.done);

    String message;
    if (subtasks.isNotEmpty && hasIncomplete) {
      message =
          'You have ${subtasks.length} subtask(s) associated with this task, including incomplete ones.\n\nWould you like to delete all associated subtasks?';
    } else if (subtasks.isNotEmpty) {
      message =
          'Are you sure you want to delete this task and all ${subtasks.length} associated subtask(s)?';
    } else {
      message = 'Are you sure you want to delete "${widget.task.title}"?';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Task',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Delete subtasks first
              for (final s in subtasks) {
                ref.read(subtasksProvider.notifier).removeSubtask(s.id);
              }
              ref.read(tasksProvider.notifier).removeTask(widget.task.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Task deleted')));
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch latest task state
    final task = ref
        .watch(tasksProvider)
        .firstWhere((t) => t.id == widget.task.id, orElse: () => widget.task);

    final users = ref.watch(systemUsersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final subtasks = ref
        .watch(subtasksProvider)
        .where((s) => s.taskId == task.id)
        .toList();
    final isAdmin = currentUser.isAdmin;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  color: task.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Task Details',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (!_isEditing) ...[
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: theme.primaryColor),
                  tooltip: 'Edit Task',
                  onPressed: () => setState(() => _isEditing = true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete Task',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          ),
          const Divider(),
          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing) ...[
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor.withOpacity(
                          0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor.withOpacity(
                          0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTile(
                            'Start',
                            _startDate,
                            () => _pickDate(true),
                            theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTile(
                            'End',
                            _endDate,
                            () => _pickDate(false),
                            theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Theme Color',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _palette
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setState(() => _color = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 32,
                                height: 32,
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
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    if (isAdmin || currentUser.isSuperAdmin)
                      MultiSelectDropdown(
                        title: 'Assigned User(s)',
                        users: users,
                        selectedIds: _assignedUserIds,
                        onChanged: (v) {
                          setState(() => _assignedUserIds = v);
                        },
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isEditing = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // View mode
                    _buildInfoRow(Icons.label, 'Title', task.title, theme),
                    if (task.description != null &&
                        task.description!.isNotEmpty)
                      _buildInfoRow(
                        Icons.description,
                        'Description',
                        task.description!,
                        theme,
                      ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Start',
                      '${task.startDate.day}/${task.startDate.month}/${task.startDate.year} ${task.startDate.hour.toString().padLeft(2, '0')}:${task.startDate.minute.toString().padLeft(2, '0')}',
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.event,
                      'End',
                      '${task.endDate.day}/${task.endDate.month}/${task.endDate.year} ${task.endDate.hour.toString().padLeft(2, '0')}:${task.endDate.minute.toString().padLeft(2, '0')}',
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.flag,
                      'Status',
                      task.status == TaskStatus.done
                          ? 'Done'
                          : (task.status == TaskStatus.inProgress
                                ? 'In Progress'
                                : 'To Do'),
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.person,
                      'Assigned',
                      users
                              .where((u) => task.assignedUserIds.contains(u.id))
                              .map((u) => u.name)
                              .firstOrNull ??
                          'Unassigned',
                      theme,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Connected Subtasks (always visible)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connected Subtasks',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => showGlassDialog(
                          context,
                          EntityCreator(
                            initialEntityType: 'Subtask',
                            initialParentPhaseId: task.projectId,
                            initialParentTaskId: task.id,
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Add Subtask',
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (subtasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No subtasks attached.',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...subtasks
                        .map(
                          (s) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: (s.color ?? widget.task.color).withOpacity(
                                0.05,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (s.color ?? widget.task.color)
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                s.status == TaskStatus.done
                                    ? Icons.check_circle
                                    : (s.status == TaskStatus.inProgress
                                          ? Icons.play_circle_fill
                                          : Icons.circle_outlined),
                                color: s.color ?? task.color,
                              ),
                              title: Text(
                                s.title,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Due ${s.endDate.day}/${s.endDate.month}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.hintColor,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: s.color ?? widget.task.color,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  showGlassDialog(
                                    context,
                                    SubtaskEditor(subtask: s),
                                  );
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                showGlassDialog(
                                  context,
                                  SubtaskEditor(subtask: s),
                                );
                              },
                            ),
                          ),
                        )
                        .toList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (!_isEditing)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime date,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 18, color: theme.primaryColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
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

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.primaryColor.withOpacity(0.7)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
