import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_module.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';
import 'client_profile_screen.dart';

class ClientCreationScreen extends ConsumerStatefulWidget {
  const ClientCreationScreen({Key? key}) : super(key: key);

  @override
  _ClientCreationScreenState createState() => _ClientCreationScreenState();
}

class _ClientCreationScreenState extends ConsumerState<ClientCreationScreen> {
  String _firstName = '';
  String _lastName = '';
  String _clientType = 'Private';
  String _assignedId = '';
  final List<Contact> _contacts = [
    const Contact(role: 'Primary Caregiver', isPrimary: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser.role == UserRole.therapist) {
        setState(() => _assignedId = currentUser.id);
      }
    });
  }

  void _addContact() {
    setState(() {
      _contacts.add(const Contact(role: 'Additional Contact'));
    });
  }

  void _removeContact(int index) {
    if (_contacts.length > 1) {
      setState(() => _contacts.removeAt(index));
    }
  }

  void _saveClient() {
    if (_firstName.isEmpty || _lastName.isEmpty) return;

    final newProject = Project(
      title: '$_firstName $_lastName - Therapy',
      firstName: _firstName,
      lastName: _lastName,
      clientId: 'new_${DateTime.now().millisecondsSinceEpoch}',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 365)),
      clientType: _clientType,
      assignedTherapistIds: [_assignedId.isEmpty ? 'unassigned' : _assignedId],
      contacts: _contacts,
    );

    ref.read(projectsProvider.notifier).addProject(newProject);

    // Automatically add Therapy Sessions task
    ref
        .read(tasksProvider.notifier)
        .addTask(
          ProjectTask(
            projectId: newProject.id,
            title: 'Therapy Sessions',
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 365)),
            color: Colors.blueAccent,
          ),
        );

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => ClientProfileScreen(clientProject: newProject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(clientTypesProvider);
    final users = ref
        .watch(systemUsersProvider)
        .where((u) => u.role == UserRole.therapist || u.role == UserRole.admin)
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Onboard New Client',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Personal Details',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _dec('First Name *', theme),
                      onChanged: (v) => _firstName = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: _dec('Last Name *', theme),
                      onChanged: (v) => _lastName = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _clientType,
                decoration: _dec('Funding / Client Type', theme),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _clientType = v!),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contacts & Stakeholders',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Contact'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_contacts.length, (i) => _contactCard(i, theme)),

              const SizedBox(height: 32),
              Text(
                'Therapist Assignment',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _assignedId.isNotEmpty ? _assignedId : null,
                decoration: _dec('Primary Clinician', theme),
                items: users
                    .map(
                      (u) => DropdownMenuItem(value: u.id, child: Text(u.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _assignedId = v!),
              ),

              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete Onboarding'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(24),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _saveClient,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactCard(int i, ThemeData theme) {
    final c = _contacts[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
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
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    isDense: true,
                  ),
                  onChanged: (v) => _contacts[i] = c.copyWith(role: v),
                ),
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  Checkbox(
                    value: c.isPrimary,
                    onChanged: (v) {
                      setState(() {
                        for (int j = 0; j < _contacts.length; j++) {
                          _contacts[j] = _contacts[j].copyWith(
                            isPrimary: j == i,
                          );
                        }
                      });
                    },
                  ),
                  Text('Primary', style: GoogleFonts.outfit(fontSize: 12)),
                ],
              ),
              if (_contacts.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: () => _removeContact(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'First Name'),
                  onChanged: (v) => _contacts[i] = c.copyWith(firstName: v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  onChanged: (v) => _contacts[i] = c.copyWith(lastName: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onChanged: (v) => _contacts[i] = c.copyWith(phone: v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  onChanged: (v) => _contacts[i] = c.copyWith(email: v),
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
    fillColor: theme.scaffoldBackgroundColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
