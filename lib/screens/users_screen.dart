import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clinic_settings.dart';
import '../models/project_module.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../widgets/dialogs/user_creator.dart';
import '../services/supabase_repository.dart';
import 'client_profile_screen.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(systemUsersProvider);
    final invites = ref.watch(invitesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Team Members',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (currentUser.isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite User',
              onPressed: () => showGlassDialog(context, const UserCreator()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...users.map((u) => _UserCard(user: u)),
          if (invites.isNotEmpty && currentUser.isAdmin) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.mail_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Pending Invitations (${invites.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...invites.map((i) => _InviteCard(invite: i)),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  final UserInvite invite;
  const _InviteCard({required this.invite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == invite.role.toLowerCase(),
      orElse: () => UserRole.therapist,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.5) ??
            theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
            child: const Icon(Icons.person_outline, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.fullName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${invite.email} • Invited as ${invite.role.toUpperCase()}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  'Sent ${DateFormat('d MMM yyyy').format(invite.createdAt)}',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: theme.hintColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Cancel Invite',
            onPressed: () => _confirmCancel(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invitation?'),
        content: Text('This will rescind the invite for ${invite.email}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              ref.read(invitesProvider.notifier).cancelInvite(invite.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rescind'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final AppUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final projects = ref.watch(projectsProvider);
    final currentClients = projects
        .where((p) => p.assignedTherapistIds.contains(user.id))
        .where((p) => !p.clientType.startsWith('Profile:'))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: user.userColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: user.userColor.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: currentUser.isAdmin || currentUser.id == user.id
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: user),
                    ),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: user.userColor.withValues(alpha: 0.15),
                  backgroundImage: (user.base64Photo != null && user.base64Photo!.isNotEmpty)
                      ? MemoryImage(base64Decode(user.base64Photo!))
                      : null,
                  child: (user.base64Photo == null || user.base64Photo!.isEmpty)
                      ? Text(
                          user.initials,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: user.userColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(user.role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.role.name.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _roleColor(user.role),
                              ),
                            ),
                          ),
                          if (user.ahpraNumber.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'AHPRA: ${user.ahpraNumber}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (currentClients.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${currentClients.length} active client${currentClients.length != 1 ? 's' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (currentUser.isAdmin && currentUser.id != user.id)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                    onPressed: () => _confirmDelete(context, ref),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final repo = SupabaseRepository();
    
    // Check dependencies
    final hasDeps = await repo.hasUserDependencies(user.id);
    
    if (!context.mounted) return;

    if (hasDeps) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete User'),
          content: Text('${user.displayName} still has clients or tasks attributed to them. Please re-assign these before deleting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${user.displayName}?', style: const TextStyle(color: Colors.red)),
        content: const Text('This will permanently remove this user from the clinic. This action cannot be undone. Are you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('DELETE USER'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(systemUsersProvider.notifier).removeUser(user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${user.displayName} removed')),
        );
      }
    }
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:
      case UserRole.administrator:
        return Colors.purple;
      case UserRole.therapist:
        return Colors.blue;
      case UserRole.receptionist:
        return Colors.green;
    }
  }
}

// ===============================================
// USER PROFILE SCREEN — full detail + edit
// ===============================================
class UserProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const UserProfileScreen({Key? key, required this.user}) : super(key: key);
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _ahpraCtrl;
  late TextEditingController _qualCtrl;
  late TextEditingController _notesCtrl;

  late Color _selectedColor;
  final ImagePicker _imagePicker = ImagePicker();

  final List<Color> _colorPalette = [
    Colors.purple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _firstCtrl = TextEditingController(text: widget.user.firstName);
    _lastCtrl = TextEditingController(text: widget.user.lastName);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
    _addressCtrl = TextEditingController(text: widget.user.address);
    _ahpraCtrl = TextEditingController(text: widget.user.ahpraNumber);
    _qualCtrl = TextEditingController(text: widget.user.qualifications);
    _notesCtrl = TextEditingController(text: widget.user.notes);
    _selectedColor = widget.user.userColor;
  }

  @override
  void dispose() {
    for (var c in [
      _nameCtrl,
      _firstCtrl,
      _lastCtrl,
      _emailCtrl,
      _phoneCtrl,
      _addressCtrl,
      _ahpraCtrl,
      _qualCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canEdit {
    final cur = ref.read(currentUserProvider);
    return cur.isAdmin || cur.id == widget.user.id;
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      try {
        await Supabase.instance.client.from('users').update({
          'photo': base64String,
        }).eq('id', widget.user.id);
        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _save() async {
    final fullName = '${_firstCtrl.text} ${_lastCtrl.text}'.trim();
    try {
      await Supabase.instance.client.from('users').update({
        'full_name': fullName.isNotEmpty ? fullName : _nameCtrl.text,
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'ahpra_number': _ahpraCtrl.text.trim(),
        'qualifications': _qualCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'user_color': '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
      }).eq('id', widget.user.id);

      // Refresh provider data
      ref.invalidate(currentUserProvider);

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = ref.watch(systemUsersProvider);
    final user = users.firstWhere(
      (u) => u.id == widget.user.id,
      orElse: () => widget.user,
    );
    final projects = ref.watch(projectsProvider);
    final seenClientIds = <String>{};
    final currentClients = <Project>[];
    for (final p in projects) {
      if (p.assignedTherapistIds.contains(user.id) && 
          !p.clientType.startsWith('Profile:') &&
          !seenClientIds.contains(p.clientId)) {
        currentClients.add(p);
        seenClientIds.add(p.clientId);
      }
    }
    final pastClients =
        <Project>[]; // Placeholder for when clients are archived

    // Keep controllers in sync only when not editing
    if (!_isEditing) {
      _firstCtrl.text = user.firstName;
      _lastCtrl.text = user.lastName;
      _emailCtrl.text = user.email;
      _phoneCtrl.text = user.phone;
      _addressCtrl.text = user.address;
      _ahpraCtrl.text = user.ahpraNumber;
      _qualCtrl.text = user.qualifications;
      _notesCtrl.text = user.notes;
      _selectedColor = user.userColor;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.displayName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_canEdit && !_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: theme.primaryColor),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    user.userColor.withValues(alpha: 0.08),
                    user.userColor.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: user.userColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: (_isEditing && _canEdit) ? _pickProfilePhoto : null,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: _selectedColor.withValues(alpha: 0.2),
                          backgroundImage: (user.base64Photo != null && user.base64Photo!.isNotEmpty)
                              ? MemoryImage(base64Decode(user.base64Photo!))
                              : null,
                          child: (user.base64Photo == null || user.base64Photo!.isEmpty)
                              ? Text(
                                  user.initials,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedColor,
                                  ),
                                )
                              : null,
                        ),
                        if (_isEditing && _canEdit)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: user.userColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.role.name.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: user.userColor,
                            ),
                          ),
                        ),
                        if (user.qualifications.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            user.qualifications,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Contact details (view / edit mode)
            if (_isEditing) ...[
              _sectionTitle('Personal Details', theme),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('First Name', _firstCtrl, theme)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Last Name', _lastCtrl, theme)),
                ],
              ),
              const SizedBox(height: 10),
              _field(
                'Email',
                _emailCtrl,
                theme,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _field('Phone', _phoneCtrl, theme, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _field('Address', _addressCtrl, theme),
              const SizedBox(height: 16),
              _sectionTitle('Professional', theme),
              const SizedBox(height: 8),
              _field('AHPRA Number', _ahpraCtrl, theme),
              const SizedBox(height: 10),
              _field('Qualifications', _qualCtrl, theme),
              const SizedBox(height: 10),
              _field('Notes', _notesCtrl, theme, maxLines: 3),
              const SizedBox(height: 20),
              _sectionTitle('Profile Colour', theme),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colorPalette.map((c) {
                  final isSelected = _selectedColor.value == c.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
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
              _sectionTitle('Contact Details', theme),
              const SizedBox(height: 8),
              _infoRow(
                Icons.email_outlined,
                'Email',
                user.email.isNotEmpty ? user.email : '—',
                theme,
              ),
              _infoRow(
                Icons.phone,
                'Phone',
                user.phone.isNotEmpty ? user.phone : '—',
                theme,
              ),
              _infoRow(
                Icons.home_outlined,
                'Address',
                user.address.isNotEmpty ? user.address : '—',
                theme,
              ),
              if (user.startDate != null)
                _infoRow(
                  Icons.calendar_today,
                  'Start Date',
                  DateFormat('d MMM yyyy').format(user.startDate!),
                  theme,
                ),
              if (user.ahpraNumber.isNotEmpty)
                _infoRow(Icons.verified_user, 'AHPRA', user.ahpraNumber, theme),
              if (user.twoFactorEnabled)
                _infoRow(Icons.security, '2FA', 'Enabled ✓', theme),

              if (user.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle('Notes', theme),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    user.notes,
                    style: GoogleFonts.outfit(fontSize: 13, height: 1.5),
                  ),
                ),
              ],

              // Current clients
              const SizedBox(height: 24),
              _sectionTitle(
                'Current Clients (${currentClients.length})',
                theme,
              ),
              const SizedBox(height: 8),
              if (currentClients.isEmpty)
                Text(
                  'No active clients assigned.',
                  style: GoogleFonts.outfit(
                    color: theme.hintColor,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...currentClients.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        c.firstName.isNotEmpty ? c.firstName[0] : '?',
                        style: GoogleFonts.outfit(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      c.clientName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${c.clientCode} • ${c.clientType}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientProfileScreen(clientProject: c),
                      ),
                    ),
                  ),
                ),

              if (pastClients.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('Past Clients (${pastClients.length})', theme),
                const SizedBox(height: 8),
                ...pastClients.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      c.clientName,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: theme.hintColor,
                      ),
                    ),
                    subtitle: Text(
                      c.clientCode,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ),
              ],

              // Tasks assigned
              const SizedBox(height: 24),
              _assignedTasksSection(theme),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _assignedTasksSection(ThemeData theme) {
    final tasks = ref
        .watch(tasksProvider)
        .where(
          (t) =>
              t.assignedUserIds.contains(widget.user.id) && t.status != TaskStatus.done,
        )
        .toList();
    final subtasks = ref
        .watch(subtasksProvider)
        .where(
          (s) =>
              s.assignedUserIds.contains(widget.user.id) && s.status != TaskStatus.done,
        )
        .toList();

    if (tasks.isEmpty && subtasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Active Assignments', theme),
          const SizedBox(height: 8),
          Text(
            'No active assignments.',
            style: GoogleFonts.outfit(
              color: theme.hintColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Active Assignments (${tasks.length + subtasks.length})',
          theme,
        ),
        const SizedBox(height: 8),
        ...tasks.map(
          (t) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 4,
              height: 30,
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
              'Due ${DateFormat('d MMM').format(t.endDate)}',
              style: GoogleFonts.outfit(fontSize: 11, color: theme.hintColor),
            ),
          ),
        ),
        ...subtasks.map(
          (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: theme.hintColor,
            ),
            title: Text(s.title, style: GoogleFonts.outfit(fontSize: 12)),
            subtitle: Text(
              'Due ${DateFormat('d MMM').format(s.endDate)}',
              style: GoogleFonts.outfit(fontSize: 11, color: theme.hintColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) => Text(
    title,
    style: GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    ),
  );

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
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 16, color: theme.primaryColor.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Text(value, style: GoogleFonts.outfit(fontSize: 13))),
      ],
    ),
  );
}
