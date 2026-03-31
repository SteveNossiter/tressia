import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/project_module.dart';
import '../../models/clinic_settings.dart';
import '../../providers/app_state.dart';
import '../../screens/client_profile_screen.dart';
import '../multi_select_dropdown.dart';
import 'glass_dialog.dart';

class ClientCreatorDialog extends ConsumerStatefulWidget {
  const ClientCreatorDialog({Key? key}) : super(key: key);

  @override
  _ClientCreatorDialogState createState() => _ClientCreatorDialogState();
}

class _ClientCreatorDialogState extends ConsumerState<ClientCreatorDialog> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Step 1 - Personal
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _dob;
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 2 - Funding
  String _clientType = 'Private';
  final _ndisNumberCtrl = TextEditingController();
  List<String> _assignedTherapistIds = [];

  // Step 3 - Contacts (NDIS-specific)
  final _pmFirstCtrl = TextEditingController(); // Plan Manager
  final _pmLastCtrl = TextEditingController();
  final _pmPhoneCtrl = TextEditingController();
  final _pmEmailCtrl = TextEditingController();

  final _pcFirstCtrl = TextEditingController(); // Plan Coordinator
  final _pcLastCtrl = TextEditingController();
  final _pcPhoneCtrl = TextEditingController();
  final _pcEmailCtrl = TextEditingController();

  final _cmhFirstCtrl = TextEditingController(); // CMH
  final _cmhLastCtrl = TextEditingController();
  final _cmhPhoneCtrl = TextEditingController();
  final _cmhEmailCtrl = TextEditingController();

  // Emergency contact (all types)
  final _ecFirstCtrl = TextEditingController();
  final _ecLastCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _ecRoleCtrl = TextEditingController();

  // Step 4 - Notes
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser.role == UserRole.therapist) {
        setState(() => _assignedTherapistIds = [currentUser.id]);
      } else {
        final eligible = ref
            .read(systemUsersProvider)
            .where(
              (u) => u.role == UserRole.therapist || u.role == UserRole.admin,
            )
            .toList();
        if (eligible.isNotEmpty) {
          setState(() => _assignedTherapistIds = [eligible.first.id]);
        }
      }
    });
  }

  @override
  void dispose() {
    for (var c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _ndisNumberCtrl,
      _pmFirstCtrl,
      _pmLastCtrl,
      _pmPhoneCtrl,
      _pmEmailCtrl,
      _pcFirstCtrl,
      _pcLastCtrl,
      _pcPhoneCtrl,
      _pcEmailCtrl,
      _cmhFirstCtrl,
      _cmhLastCtrl,
      _cmhPhoneCtrl,
      _cmhEmailCtrl,
      _ecFirstCtrl,
      _ecLastCtrl,
      _ecPhoneCtrl,
      _ecRoleCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _generateClientCode() {
    final existing = ref.read(projectsProvider);
    final idx = existing.length;
    return generateClientCode(
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
      idx,
    );
  }

  Future<void> _saveClient() async {
    if (_firstNameCtrl.text.trim().isEmpty) return;

    final code = _generateClientCode();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    final title = '$firstName $lastName'.trim();
    final newProject = Project(
      title: title,
      clientId: 'c_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      clientCode: code,
      dateOfBirth: _dob,
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      clientType: 'Profile: $_clientType',
      ndisNumber: _ndisNumberCtrl.text.trim(),
      assignedTherapistIds: _assignedTherapistIds,
      contacts: [
        if (_clientType == 'NDIS' && _pmFirstCtrl.text.isNotEmpty)
          Contact(
            firstName: _pmFirstCtrl.text.trim(),
            lastName: _pmLastCtrl.text.trim(),
            phone: _pmPhoneCtrl.text.trim(),
            email: _pmEmailCtrl.text.trim(),
            role: 'Plan Manager',
          ),
        if (_clientType == 'NDIS' && _pcFirstCtrl.text.isNotEmpty)
          Contact(
            firstName: _pcFirstCtrl.text.trim(),
            lastName: _pcLastCtrl.text.trim(),
            phone: _pcPhoneCtrl.text.trim(),
            email: _pcEmailCtrl.text.trim(),
            role: 'Plan Coordinator',
          ),
        if (_cmhFirstCtrl.text.isNotEmpty)
          Contact(
            firstName: _cmhFirstCtrl.text.trim(),
            lastName: _cmhLastCtrl.text.trim(),
            phone: _cmhPhoneCtrl.text.trim(),
            email: _cmhEmailCtrl.text.trim(),
            role: 'CMH Coordinator',
          ),
        if (_ecFirstCtrl.text.isNotEmpty)
          Contact(
            firstName: _ecFirstCtrl.text.trim(),
            lastName: _ecLastCtrl.text.trim(),
            phone: _ecPhoneCtrl.text.trim(),
            role: _ecRoleCtrl.text.trim(),
            isPrimary: true,
          ),
      ],
      notes: _notesCtrl.text.trim(),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 365)),
    );

    try {
      await ref.read(projectsProvider.notifier).addProject(newProject);
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => ClientProfileScreen(clientProject: newProject),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving client: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = ref
        .watch(systemUsersProvider)
        .where((u) => u.role == UserRole.therapist || u.role == UserRole.admin)
        .toList();
    final currentUser = ref.watch(currentUserProvider);
    final types = ref.watch(clientTypesProvider);
    final isNDIS = _clientType == 'NDIS';

    final steps = [
      _buildPersonalStep(theme),
      _buildFundingStep(theme, types, users, currentUser),
      _buildContactsStep(theme, isNDIS),
      _buildNotesStep(theme),
    ];

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Icon(Icons.person_add, color: theme.primaryColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New Client Onboarding',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Step indicators
                ...List.generate(
                  steps.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentStep
                          ? theme.primaryColor
                          : i < _currentStep
                          ? theme.primaryColor.withValues(alpha: 0.4)
                          : theme.dividerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Step content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: steps[_currentStep]),
            ),
          ),
          // Navigation buttons
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentStep < steps.length - 1) {
                        if (_firstNameCtrl.text.trim().isEmpty &&
                            _currentStep == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('First name is required'),
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      } else {
                        _saveClient();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _currentStep < steps.length - 1
                          ? 'Next'
                          : 'Complete Onboarding',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // STEP 1 — Personal Details
  // =============================================
  Widget _buildPersonalStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('1. Personal Details', Icons.person, theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _field(
                'First Name *',
                _firstNameCtrl,
                theme,
                required: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _field('Last Name', _lastNameCtrl, theme)),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => _dob = d);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.cake, size: 18, color: theme.hintColor),
                const SizedBox(width: 12),
                Text(
                  _dob != null
                      ? 'DOB: ${_dob!.day}/${_dob!.month}/${_dob!.year}'
                      : 'Date of Birth (tap to select)',
                  style: GoogleFonts.outfit(
                    color: _dob != null
                        ? theme.colorScheme.onSurface
                        : theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _field('Address', _addressCtrl, theme),
        const SizedBox(height: 12),
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
            const SizedBox(width: 12),
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
      ],
    );
  }

  // =============================================
  // STEP 2 — Funding & Assignment
  // =============================================
  Widget _buildFundingStep(
    ThemeData theme,
    List<String> types,
    List<AppUser> users,
    AppUser currentUser,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          '2. Funding & Therapist',
          Icons.account_balance_wallet,
          theme,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _clientType,
                decoration: _dec('Funding / Client Type', theme),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _clientType = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: theme.primaryColor),
                tooltip: 'Add new category',
                onPressed: () async {
                  final newTypeCtrl = TextEditingController();
                  final newType = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.cardTheme.color,
                      title: Text(
                        'New Funding Type',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      content: TextField(
                        controller: newTypeCtrl,
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. DVA',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(color: theme.hintColor),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              Navigator.pop(ctx, newTypeCtrl.text.trim()),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                  if (newType != null &&
                      newType.isNotEmpty &&
                      !types.contains(newType)) {
                    ref.read(clientTypesProvider.notifier).addType(newType);
                    setState(() => _clientType = newType);
                  }
                },
              ),
            ),
          ],
        ),
        if (_clientType == 'NDIS') ...[
          const SizedBox(height: 12),
          _field('NDIS Number', _ndisNumberCtrl, theme),
        ],
        const SizedBox(height: 24),
        _sectionLabel('Assigned Therapist', theme),
        const SizedBox(height: 8),
        if (currentUser.role == UserRole.therapist)
          _infoTile(
            currentUser.name,
            'Automatically assigned to you',
            Icons.lock,
            theme,
          )
        else
          MultiSelectDropdown(
            title: 'Therapist(s)',
            users: users,
            selectedIds: _assignedTherapistIds,
            onChanged: (v) {
              setState(() => _assignedTherapistIds = v);
            },
          ),
      ],
    );
  }

  // =============================================
  // STEP 3 — Contacts
  // =============================================
  Widget _buildContactsStep(ThemeData theme, bool isNDIS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('3. Contacts', Icons.contacts, theme),
        const SizedBox(height: 16),
        if (isNDIS) ...[
          _sectionLabel('Plan Manager', theme),
          const SizedBox(height: 8),
          _contactFields(
            _pmFirstCtrl,
            _pmLastCtrl,
            _pmPhoneCtrl,
            _pmEmailCtrl,
            theme,
          ),
          const SizedBox(height: 20),
          _sectionLabel('Plan Coordinator', theme),
          const SizedBox(height: 8),
          _contactFields(
            _pcFirstCtrl,
            _pcLastCtrl,
            _pcPhoneCtrl,
            _pcEmailCtrl,
            theme,
          ),
          const SizedBox(height: 20),
        ],
        _sectionLabel('Community Mental Health (CMH) Contact', theme),
        const SizedBox(height: 8),
        _contactFields(
          _cmhFirstCtrl,
          _cmhLastCtrl,
          _cmhPhoneCtrl,
          _cmhEmailCtrl,
          theme,
        ),
        const SizedBox(height: 20),
        _sectionLabel('Emergency Contact', theme),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _field('First Name', _ecFirstCtrl, theme)),
            const SizedBox(width: 8),
            Expanded(child: _field('Last Name', _ecLastCtrl, theme)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _field(
                'Phone',
                _ecPhoneCtrl,
                theme,
                keyboard: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Relationship',
                _ecRoleCtrl,
                theme,
                hint: 'e.g. Sister',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================
  // STEP 4 — Notes
  // =============================================
  Widget _buildNotesStep(ThemeData theme) {
    final code = _firstNameCtrl.text.isNotEmpty
        ? generateClientCode(
            _firstNameCtrl.text,
            _lastNameCtrl.text,
            ref.read(projectsProvider).length,
          )
        : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          '4. Notes & Confirmation',
          Icons.check_circle_outline,
          theme,
        ),
        const SizedBox(height: 16),
        // Summary preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Onboarding Summary',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              _previewRow(
                'Client',
                '${_firstNameCtrl.text} ${_lastNameCtrl.text}',
                theme,
              ),
              _previewRow('Code', code, theme),
              _previewRow('Type', _clientType, theme),
              _previewRow(
                'Phone',
                _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '—',
                theme,
              ),
              _previewRow(
                'Email',
                _emailCtrl.text.isNotEmpty ? _emailCtrl.text : '—',
                theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Initial Notes',
            hintText: 'Goals, referral source, clinical notes...',
            filled: true,
            fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Onboarding forms will be generated based on $_clientType funding type.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =============================================
  // HELPERS
  // =============================================
  Widget _stepTitle(String title, IconData icon, ThemeData theme) => Row(
    children: [
      Icon(icon, color: theme.primaryColor, size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ],
  );

  Widget _sectionLabel(String label, ThemeData theme) => Text(
    label,
    style: GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.hintColor,
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    bool required = false,
    TextInputType? keyboard,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
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

  InputDecoration _dec(String label, ThemeData theme) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _contactFields(
    TextEditingController first,
    TextEditingController last,
    TextEditingController phone,
    TextEditingController email,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _field('First Name', first, theme)),
            const SizedBox(width: 8),
            Expanded(child: _field('Last Name', last, theme)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _field(
                'Phone',
                phone,
                theme,
                keyboard: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Email',
                email,
                theme,
                keyboard: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(
    String title,
    String subtitle,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.hintColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
