import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  late TextEditingController _userFirstNameCtrl;
  late TextEditingController _userLastNameCtrl;
  late TextEditingController _userAhpraCtrl;

  @override
  void initState() {
    super.initState();
    final current = ref.read(clinicSettingsProvider);
    final user = ref.read(currentUserProvider);

    _nameCtrl = TextEditingController(text: current.clinicName);
    _descCtrl = TextEditingController(text: current.description);
    _addressCtrl = TextEditingController(text: current.address);
    _phoneCtrl = TextEditingController(text: current.phone);
    _emailCtrl = TextEditingController(text: current.email);

    _userFirstNameCtrl = TextEditingController(text: user.firstName);
    _userLastNameCtrl = TextEditingController(text: user.lastName);
    _userAhpraCtrl = TextEditingController(text: user.ahpraNumber);
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

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  void _completeSetup() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      final currentClinic = ref.read(clinicSettingsProvider);

      // Save Personal Details
      await Supabase.instance.client.from('users').update({
        'full_name': '${_userFirstNameCtrl.text} ${_userLastNameCtrl.text}'.trim(),
        'ahpra_number': _userAhpraCtrl.text.trim(),
        'setup_complete': true,
      }).eq('id', currentUser.id);

      // Save Clinic Details (if admin)
      if (currentUser.isAdmin) {
        await Supabase.instance.client.from('clinics').update({
          'name': _nameCtrl.text,
          'description': _descCtrl.text,
          'address': _addressCtrl.text,
          'phone': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'setup_complete': true,
        }).eq('id', currentClinic.id);
      }

      // Force providers to re-fetch the updated data
      ref.invalidate(currentUserProvider);
      ref.invalidate(clinicSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setup Complete! Loading dashboard...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing setup: $e'),
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
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.isAdmin;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              'Initial Account Setup',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            floating: true,
            actions: [
              TextButton(
                onPressed: _logout,
                child: Text('LOGOUT', style: GoogleFonts.outfit(color: Colors.red)),
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
                    // PERSONAL SECTION
                    _sectionHeader(theme, '1. Personal Profile'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userFirstNameCtrl,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _userLastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _userAhpraCtrl,
                      decoration: const InputDecoration(labelText: 'AHPRA Number (if applicable)'),
                    ),
                    
                    const SizedBox(height: 48),

                    // CLINIC SECTION (Only for App Admins/Registrants)
                    if (isAdmin) ...[
                      _sectionHeader(theme, '2. Clinic Identity'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Clinic / Business Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Short Description'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Clinic Address'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Public Email'),
                      ),
                    ],

                    const SizedBox(height: 64),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _completeSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'COMPLETE SETUP & START',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor,
      ),
    );
  }
}
