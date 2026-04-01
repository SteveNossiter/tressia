import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/project_module.dart';
import '../../providers/app_state.dart';
import '../../theme/organic_palette.dart';
import '../multi_select_dropdown.dart';

class SubtaskEditor extends ConsumerStatefulWidget {
  final Subtask subtask;
  const SubtaskEditor({Key? key, required this.subtask}) : super(key: key);

  @override
  _SubtaskEditorState createState() => _SubtaskEditorState();
}

class _SubtaskEditorState extends ConsumerState<SubtaskEditor> {
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  Color? _color;
  List<String> _assignedUserIds = [];
  late TaskStatus _status;

  final List<Color> _palette = OrganicPalette.colors;

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color ?? widget.subtask.color ?? Colors.blue,
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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.subtask.title);
    _descCtrl = TextEditingController(text: widget.subtask.description ?? '');
    _startDate = widget.subtask.startDate;
    _endDate = widget.subtask.endDate;
    _color = widget.subtask.color;
    _assignedUserIds = List.from(widget.subtask.assignedUserIds);
    _status = widget.subtask.status;
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
    final upd = widget.subtask.copyWith(
      title: _titleCtrl.text,
      description: _descCtrl.text,
      startDate: _startDate,
      endDate: _endDate,
      color: _color,
      assignedUserIds: _assignedUserIds,
      status: _status,
    );
    ref.read(subtasksProvider.notifier).updateSubtask(upd);
    setState(() => _isEditing = false);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Subtask',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.subtask.title}"?',
          style: GoogleFonts.outfit(),
        ),
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
              ref
                  .read(subtasksProvider.notifier)
                  .removeSubtask(widget.subtask.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Subtask deleted')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch latest subtask state
    final subtask = ref
        .watch(subtasksProvider)
        .firstWhere(
          (s) => s.id == widget.subtask.id,
          orElse: () => widget.subtask,
        );

    final users = ref.watch(systemUsersProvider);
    final currentUser = ref.watch(currentUserProvider);
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
              Icon(
                subtask.status == TaskStatus.done
                    ? Icons.check_circle
                    : (subtask.status == TaskStatus.inProgress
                          ? Icons.play_circle_fill
                          : Icons.circle_outlined),
                color: subtask.color ?? theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Subtask Details',
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
                  tooltip: 'Edit Subtask',
                  onPressed: () => setState(() => _isEditing = true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete Subtask',
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
                        labelText: 'Subtask Title',
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
                    // Status selector
                    Text(
                      'Status',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: TaskStatus.values.map((s) {
                        bool sel = _status == s;
                        Color chipColor = s == TaskStatus.done
                            ? Colors.green
                            : (s == TaskStatus.inProgress
                                  ? Colors.orange
                                  : theme.hintColor);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                _statusLabel(s),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              selected: sel,
                              selectedColor: chipColor,
                              backgroundColor: theme.scaffoldBackgroundColor,
                              onSelected: (v) {
                                if (v) setState(() => _status = s);
                              },
                            ),
                          ),
                        );
                      }).toList(),
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
                      'Subtask Color',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._palette.take(9).map(
                              (c) => GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: _color?.value == c.value
                                        ? Border.all(
                                            color: theme.colorScheme.onSurface,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: _color?.value == c.value
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        GestureDetector(
                          onTap: _showColorPicker,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: _color != null && !_palette.any((pc) => pc.value == _color!.value)
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              Icons.colorize,
                              size: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
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
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // View mode
                    _buildInfoRow(Icons.label, 'Title', subtask.title, theme),
                    if (subtask.description != null &&
                        subtask.description!.isNotEmpty)
                      _buildInfoRow(
                        Icons.description,
                        'Description',
                        subtask.description!,
                        theme,
                      ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Start',
                      '${subtask.startDate.day}/${subtask.startDate.month}/${subtask.startDate.year} ${subtask.startDate.hour.toString().padLeft(2, '0')}:${subtask.startDate.minute.toString().padLeft(2, '0')}',
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.event,
                      'End',
                      '${subtask.endDate.day}/${subtask.endDate.month}/${subtask.endDate.year} ${subtask.endDate.hour.toString().padLeft(2, '0')}:${subtask.endDate.minute.toString().padLeft(2, '0')}',
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.flag,
                      'Status',
                      _statusLabel(subtask.status),
                      theme,
                    ),
                    _buildInfoRow(
                      Icons.person,
                      'Assigned',
                      users
                              .where((u) => subtask.assignedUserIds.contains(u.id))
                              .map((u) => u.name)
                              .firstOrNull ??
                          'Unassigned',
                      theme,
                    ),
                  ],
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
