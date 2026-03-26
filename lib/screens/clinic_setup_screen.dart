import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/user_creator.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../services/pdf_generator_service.dart';

class ClinicSetupScreen extends ConsumerStatefulWidget {
  const ClinicSetupScreen({Key? key}) : super(key: key);

  @override
  _ClinicSetupScreenState createState() => _ClinicSetupScreenState();
}

class _ClinicSetupScreenState extends ConsumerState<ClinicSetupScreen> {
  final _picker = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final current = ref.read(clinicSettingsProvider);
    _nameCtrl = TextEditingController(text: current.clinicName);
    _descCtrl = TextEditingController(text: current.description);
    _addressCtrl = TextEditingController(text: current.address);
    _phoneCtrl = TextEditingController(text: current.phone);
    _emailCtrl = TextEditingController(text: current.email);
  }

  Future<void> _pickLogo() async {
    final currentUser = ref.read(currentUserProvider);
    if (!currentUser.isAdmin) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      final current = ref.read(clinicSettingsProvider);
      ref
          .read(clinicSettingsProvider.notifier)
          .updateSettings(current.copyWith(base64Logo: base64String));
    }
  }

  void _saveSettings() {
    final currentUser = ref.read(currentUserProvider);
    if (!currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Admins can modify clinic details.')),
      );
      return;
    }

    final current = ref.read(clinicSettingsProvider);
    ref
        .read(clinicSettingsProvider.notifier)
        .updateSettings(
          current.copyWith(
            clinicName: _nameCtrl.text,
            description: _descCtrl.text,
            address: _addressCtrl.text,
            phone: _phoneCtrl.text,
            email: _emailCtrl.text,
          ),
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Clinic Settings Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSettings = ref.watch(clinicSettingsProvider);
    final systemUsers = ref.watch(systemUsersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.isAdmin;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              'Clinic Configuration',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            floating: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined),
                onPressed: () => DocumentGenerator.generateBlankLetterhead(
                  context: context,
                  settings: currentSettings,
                ),
                tooltip: 'Print Blank Letterhead',
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveSettings,
                ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branding & Description',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickLogo,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.2),
                          ),
                        ),
                        child: currentSettings.base64Logo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  base64Decode(currentSettings.base64Logo!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 32,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Logo',
                                    style: GoogleFonts.outfit(
                                      color: theme.hintColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descCtrl,
                      enabled: isAdmin,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Clinic Description (Internal)',
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Contact Details',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      enabled: isAdmin,
                      decoration: const InputDecoration(
                        labelText: 'Clinic Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      enabled: isAdmin,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      enabled: isAdmin,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      enabled: isAdmin,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'System Directory',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () =>
                                showGlassDialog(context, const UserCreator()),
                            icon: const Icon(Icons.person_add),
                            label: const Text("Add User"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...systemUsers
                        .map(
                          (u) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: u.userColor.withOpacity(0.2),
                                child: Icon(Icons.person, color: u.userColor),
                              ),
                              title: Text(
                                u.name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                u.role.name.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                              ),
                              trailing: isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      onPressed: () {},
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
