import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/project_module.dart';
import '../../providers/app_state.dart';
import '../../screens/client_profile_screen.dart';
import 'task_editor.dart';
import 'entity_creator.dart';
import 'glass_dialog.dart';
import '../multi_select_dropdown.dart';

class PhaseEditor extends ConsumerStatefulWidget {
  final Project project;
  const PhaseEditor({Key? key, required this.project}) : super(key: key);

  @override
  _PhaseEditorState createState() => _PhaseEditorState();
}

class _PhaseEditorState extends ConsumerState<PhaseEditor> {
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _ndisCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _clientType;
  List<String> _assignedTherapistIds = [];
  late List<Contact> _contacts;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleCtrl = TextEditingController(text: p.title);
    _firstNameCtrl = TextEditingController(text: p.firstName);
    _lastNameCtrl = TextEditingController(text: p.lastName);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email);
    _addressCtrl = TextEditingController(text: p.address);
    _notesCtrl = TextEditingController(text: p.notes);
    _ndisCtrl = TextEditingController(text: p.ndisNumber);
    _startDate = p.startDate;
    _endDate = p.endDate;
    _clientType = p.clientType;
    _assignedTherapistIds = List.from(p.assignedTherapistIds);
    _contacts = List.from(p.contacts);
  }

  @override
  void dispose() {
    for (var c in [
      _titleCtrl,
      _firstNameCtrl,
      _lastNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _notesCtrl,
      _ndisCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null)
      setState(() {
        if (isStart)
          _startDate = d;
        else
          _endDate = d;
      });
  }

  void _save() {
    final upd = widget.project.copyWith(
      title: _titleCtrl.text.isNotEmpty
          ? _titleCtrl.text
          : widget.project.title,
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      address: _addressCtrl.text,
      notes: _notesCtrl.text,
      ndisNumber: _ndisCtrl.text,
      startDate: _startDate,
      endDate: _endDate,
      clientType: _clientType,
      assignedTherapistIds: _assignedTherapistIds,
      contacts: _contacts,
    );
    ref.read(projectsProvider.notifier).updateProject(upd);
    setState(() => _isEditing = false);
  }

  void _confirmDeletePhase(BuildContext context, List<ProjectTask> tasks) {
    final subtasks = ref.read(subtasksProvider);
    final allSubs = subtasks
        .where((s) => tasks.any((t) => t.id == s.taskId))
        .toList();
    final hasIncomplete =
        tasks.any((t) => t.status != TaskStatus.done) ||
        allSubs.any((s) => s.status != TaskStatus.done);

    final isProfile = widget.project.clientType.startsWith('Profile:');
    final titleString = isProfile ? 'Full Client Profile' : 'Client Course';
    
    String message;
    if (isProfile) {
      message = 'CAUTION: This will permanently delete the entire profile for "${widget.project.clientName}", including all their demographic details and clinical associations. This cannot be undone.\n\nAre you absolutely sure?';
    } else if (hasIncomplete) {
      message = 'You still have incomplete tasks and subtasks in this client course/project.\n\nAre you sure you want to delete "${widget.project.title}" and all associated items?';
    } else {
      message = 'Are you sure you want to delete "${widget.project.title}"?';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete $titleString',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isProfile ? Colors.red : null),
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
            onPressed: () async {
              try {
                // Cascade delete: subtasks → tasks → project
                for (final s in allSubs) {
                  await ref.read(subtasksProvider.notifier).removeSubtask(s.id);
                }
                for (final t in tasks) {
                  await ref.read(tasksProvider.notifier).removeTask(t.id);
                }
                await ref
                    .read(projectsProvider.notifier)
                    .removeProject(widget.project.id);
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  if (isProfile) {
                    Navigator.pop(context);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isProfile ? 'Client profile deleted' : 'Client course deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting project: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
    // Always watch the LATEST version from provider
    final p = ref
        .watch(projectsProvider)
        .firstWhere(
          (p) => p.id == widget.project.id,
          orElse: () => widget.project,
        );

    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.projectId == p.id)
        .toList();
    final subtasks = ref.watch(subtasksProvider);
    final users = ref.watch(systemUsersProvider);
    final clientTypes = ref.watch(clientTypesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  p.clientType == 'Internal Project'
                      ? 'Project Details'
                      : 'Client Course Details',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isEditing) ...[
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: theme.primaryColor),
                  tooltip: 'Edit',
                  onPressed: () => setState(() => _isEditing = true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDeletePhase(context, tasks),
                ),
                IconButton(
                  icon: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: theme.hintColor,
                  ),
                  tooltip: 'Open Full Profile',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => ClientProfileScreen(clientProject: p),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing) ...[
                    // Edit fields
                    _field('First Name', _firstNameCtrl, theme),
                    const SizedBox(height: 10),
                    _field('Last Name', _lastNameCtrl, theme),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Phone',
                            _phoneCtrl,
                            theme,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            'Email',
                            _emailCtrl,
                            theme,
                            keyboard: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field('Address', _addressCtrl, theme),
                    const SizedBox(height: 10),
                    if (p.clientType != 'Internal Project') ...[
                      DropdownButtonFormField<String>(
                        value: clientTypes.contains(_clientType)
                            ? _clientType
                            : null,
                        decoration: _dec('Client Type', theme),
                        items: clientTypes
                            .where((t) => t != 'Internal Project')
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _clientType = v);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_clientType == 'NDIS') ...[
                      const SizedBox(height: 10),
                      _field('NDIS Number', _ndisCtrl, theme),
                    ],
                    const SizedBox(height: 10),
                    MultiSelectDropdown(
                      title: 'Assigned Therapist(s)',
                      users: users,
                      selectedIds: _assignedTherapistIds,
                      onChanged: (v) {
                        setState(() => _assignedTherapistIds = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    _field('Notes', _notesCtrl, theme, maxLines: 3),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 10),
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
                    _infoRow(Icons.person, 'Name', p.clientName, theme),
                    _infoRow(Icons.tag, 'Code', p.clientCodeDisplay, theme),
                    _infoRow(Icons.category, 'Type', p.clientType, theme),
                    if (p.clientType == 'NDIS' && p.ndisNumber.isNotEmpty)
                      _infoRow(Icons.numbers, 'NDIS #', p.ndisNumber, theme),
                    _infoRow(
                      Icons.phone,
                      'Phone',
                      p.phone.isNotEmpty ? p.phone : '—',
                      theme,
                    ),
                    _infoRow(
                      Icons.email_outlined,
                      'Email',
                      p.email.isNotEmpty ? p.email : '—',
                      theme,
                    ),
                    _infoRow(
                      Icons.home,
                      'Address',
                      p.address.isNotEmpty ? p.address : '—',
                      theme,
                    ),
                    _infoRow(
                      Icons.badge,
                      'Therapist',
                      users
                              .where((u) => p.assignedTherapistIds.contains(u.id))
                              .map((u) => u.name)
                              .firstOrNull ??
                          '—',
                      theme,
                    ),
                    _infoRow(
                      Icons.calendar_today,
                      'Start',
                      DateFormat('d MMM yyyy').format(p.startDate),
                      theme,
                    ),
                    _infoRow(
                      Icons.event,
                      'End',
                      DateFormat('d MMM yyyy').format(p.endDate),
                      theme,
                    ),
                    if (p.contacts.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Contacts & Stakeholders',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...p.contacts.map(
                        (c) => _contactSection(c.role, c, theme),
                      ),
                    ],
                    if (p.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Notes',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p.notes,
                          style: GoogleFonts.outfit(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Contacts',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _contacts.add(
                              const Contact(role: 'New Contact'),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    ...List.generate(
                      _contacts.length,
                      (i) => _contactEditor(i, theme),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Connected Tasks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connected Tasks (${tasks.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => showGlassDialog(
                          context,
                          EntityCreator(
                            initialEntityType: 'Task',
                            initialParentPhaseId: widget.project.id,
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Add Task',
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tasks.isEmpty)
                    Text(
                      'No tasks attached yet.',
                      style: GoogleFonts.outfit(
                        color: theme.hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...tasks.map((t) {
                      final tSubs = subtasks
                          .where((s) => s.taskId == t.id)
                          .toList();
                      final done = tSubs
                          .where((s) => s.status == TaskStatus.done)
                          .length;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: t.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Text(
                          t.title,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${tSubs.isEmpty ? "No subtasks" : "$done/${tSubs.length} done"}  •  Due ${t.endDate.day}/${t.endDate.month}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          showGlassDialog(context, TaskEditor(task: t));
                        },
                      );
                    }),
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

  Widget _field(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: _dec(label, theme),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: theme.primaryColor),
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

  Widget _infoRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.primaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
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
  }

  Widget _contactSection(String sectionTitle, Contact c, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sectionTitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.isPrimary ? theme.primaryColor : theme.hintColor,
                ),
              ),
              if (c.isPrimary) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
          const SizedBox(height: 4),
          _infoRow(Icons.person, 'Name', c.fullName, theme),
          if (c.phone.isNotEmpty)
            _infoRow(Icons.phone, 'Phone', c.phone, theme),
          if (c.email.isNotEmpty)
            _infoRow(Icons.email_outlined, 'Email', c.email, theme),
        ],
      ),
    );
  }

  Widget _contactEditor(int i, ThemeData theme) {
    final c = _contacts[i];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isPrimary
              ? theme.primaryColor
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: c.role,
                  decoration: _dec('Role', theme),
                  onChanged: (v) => _contacts[i] = c.copyWith(role: v),
                ),
              ),
              Checkbox(
                value: c.isPrimary,
                onChanged: (v) {
                  setState(() {
                    for (int j = 0; j < _contacts.length; j++) {
                      _contacts[j] = _contacts[j].copyWith(isPrimary: j == i);
                    }
                  });
                },
              ),
              Text('Primary', style: GoogleFonts.outfit(fontSize: 11)),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                onPressed: () {
                  setState(() => _contacts.removeAt(i));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: c.firstName,
                  decoration: _dec('First', theme),
                  onChanged: (v) => _contacts[i] = c.copyWith(firstName: v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: c.lastName,
                  decoration: _dec('Last', theme),
                  onChanged: (v) => _contacts[i] = c.copyWith(lastName: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
