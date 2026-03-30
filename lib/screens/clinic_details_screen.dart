import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';

class ClinicDetailsScreen extends ConsumerStatefulWidget {
  const ClinicDetailsScreen({Key? key}) : super(key: key);

  @override
  _ClinicDetailsScreenState createState() => _ClinicDetailsScreenState();
}

class _ClinicDetailsScreenState extends ConsumerState<ClinicDetailsScreen> {
  final _picker = ImagePicker();
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final clinic = ref.read(clinicSettingsProvider);
    _nameCtrl = TextEditingController(text: clinic.clinicName);
    _descCtrl = TextEditingController(text: clinic.description);
    _addressCtrl = TextEditingController(text: clinic.address);
    _phoneCtrl = TextEditingController(text: clinic.phone);
    _emailCtrl = TextEditingController(text: clinic.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final currentUser = ref.read(currentUserProvider);
    if (!currentUser.isAdmin) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      try {
        final clinic = ref.read(clinicSettingsProvider);
        await Supabase.instance.client.from('clinics').update({
          'logo': base64String,
        }).eq('id', clinic.id);
        ref.invalidate(clinicSettingsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating logo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final clinic = ref.read(clinicSettingsProvider);
      await Supabase.instance.client.from('clinics').update({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      }).eq('id', clinic.id);

      ref.invalidate(clinicSettingsProvider);
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic details saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clinic = ref.watch(clinicSettingsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.isAdmin;

    // Keep controllers in sync when not editing
    if (!_isEditing) {
      _nameCtrl.text = clinic.clinicName;
      _descCtrl.text = clinic.description;
      _addressCtrl.text = clinic.address;
      _phoneCtrl.text = clinic.phone;
      _emailCtrl.text = clinic.email;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Clinic Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isAdmin && !_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: theme.primaryColor),
              tooltip: 'Edit Clinic Details',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo & Name Header
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isAdmin ? _pickLogo : null,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: (clinic.base64Logo != null && clinic.base64Logo!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.memory(
                                base64Decode(clinic.base64Logo!),
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 40,
                                  color: theme.primaryColor.withValues(alpha: 0.4),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Upload Logo',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: theme.primaryColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) ...[
                    Text(
                      clinic.clinicName.isNotEmpty ? clinic.clinicName : 'Clinic Name',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (clinic.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        clinic.description,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: theme.hintColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (_isEditing) ...[
              // Edit mode
              _sectionHeader(theme, 'Clinic Information'),
              const SizedBox(height: 16),
              _buildField('Clinic / Business Name', _nameCtrl, theme),
              const SizedBox(height: 12),
              _buildField('Short Description', _descCtrl, theme, maxLines: 2),
              const SizedBox(height: 12),
              _buildField('Clinic Address', _addressCtrl, theme),
              const SizedBox(height: 12),
              _buildField('Contact Phone', _phoneCtrl, theme,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('Public Email', _emailCtrl, theme,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() => _isEditing = false);
                              // Reset controllers
                              _nameCtrl.text = clinic.clinicName;
                              _descCtrl.text = clinic.description;
                              _addressCtrl.text = clinic.address;
                              _phoneCtrl.text = clinic.phone;
                              _emailCtrl.text = clinic.email;
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // View mode
              _sectionHeader(theme, 'Contact Information'),
              const SizedBox(height: 12),
              _infoRow(Icons.location_on_outlined, 'Address',
                  clinic.address.isNotEmpty ? clinic.address : '—', theme),
              _infoRow(Icons.phone_outlined, 'Phone',
                  clinic.phone.isNotEmpty ? clinic.phone : '—', theme),
              _infoRow(Icons.email_outlined, 'Email',
                  clinic.email.isNotEmpty ? clinic.email : '—', theme),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) => Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor,
        ),
      );

  Widget _buildField(String label, TextEditingController ctrl, ThemeData theme,
      {int maxLines = 1, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ThemeData theme) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.primaryColor.withValues(alpha: 0.7)),
            const SizedBox(width: 16),
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
              child: Text(value, style: GoogleFonts.outfit(fontSize: 14)),
            ),
          ],
        ),
      );
}
