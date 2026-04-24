import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/user_creator.dart';
import '../widgets/dialogs/glass_dialog.dart';

class ClinicSetupScreen extends ConsumerStatefulWidget {
  const ClinicSetupScreen({super.key});

  @override
  _ClinicSetupScreenState createState() => _ClinicSetupScreenState();
}

class _ClinicSetupScreenState extends ConsumerState<ClinicSetupScreen> {
  final _picker = ImagePicker();
  List<UserAssociation> _userAssociations = [];

  late TextEditingController _userFirstNameCtrl, _userLastNameCtrl, _userPhoneCtrl, _userAddressCtrl, _userEmailCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);

    _userFirstNameCtrl = TextEditingController(text: user.firstName);
    _userLastNameCtrl = TextEditingController(text: user.lastName);
    _userPhoneCtrl = TextEditingController(text: user.phone);
    _userAddressCtrl = TextEditingController(text: user.address);
    _userEmailCtrl = TextEditingController(text: user.email);
    _userAssociations = List.from(user.associations);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  void _completeSetup() async {
    try {
      final currentUser = ref.read(currentUserProvider);

      // Save Personal Details
      await Supabase.instance.client.from('users').update({
        'full_name': '${_userFirstNameCtrl.text} ${_userLastNameCtrl.text}'.trim(),
        'phone': _userPhoneCtrl.text.trim(),
        'address': _userAddressCtrl.text.trim(),
        'email': _userEmailCtrl.text.trim(),
        'associations': _userAssociations.map((e) => e.toJson()).toList(),
        'setup_complete': true,
      }).eq('id', currentUser.id);

      // Force providers to re-fetch the updated data
      ref.invalidate(currentUserProvider);

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
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            title: Text(
              'Initial Account Setup',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            floating: true,
            actions: [
              TextButton(
                onPressed: _logout,
                child: Text('LOGOUT', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _userFirstNameCtrl,
                            decoration: const InputDecoration(labelText: 'First Name'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _userLastNameCtrl,
                            decoration: const InputDecoration(labelText: 'Last Name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userEmailCtrl,
                      decoration: const InputDecoration(labelText: 'Public / Work Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userPhoneCtrl,
                      decoration: const InputDecoration(labelText: 'Public / Work Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userAddressCtrl,
                      decoration: const InputDecoration(labelText: 'Mailing Address (Optional)'),
                    ),
                    
                    const SizedBox(height: 32),
                    Text(
                      'Professional Associations',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: theme.hintColor),
                    ),
                    const SizedBox(height: 12),
                    
                    ..._userAssociations.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var assoc = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: ['ANZACATA', 'PACFA', 'ACA', 'ACA (Level 1)', 'ACA (Level 2)', 'Other'].contains(assoc.name) ? assoc.name : 'Other',
                                decoration: const InputDecoration(labelText: 'Association'),
                                items: ['ANZACATA', 'PACFA', 'ACA', 'ACA (Level 1)', 'ACA (Level 2)', 'Other']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _userAssociations[idx] = UserAssociation(name: v, membershipNumber: assoc.membershipNumber);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'Membership #'),
                                onChanged: (v) {
                                  _userAssociations[idx] = UserAssociation(name: assoc.name, membershipNumber: v);
                                },
                                controller: TextEditingController(text: assoc.membershipNumber)..selection = TextSelection.fromPosition(TextPosition(offset: assoc.membershipNumber.length)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _userAssociations.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _userAssociations.add(UserAssociation(name: 'ANZACATA', membershipNumber: ''));
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('ADD ASSOCIATION'),
                    ),

                    const SizedBox(height: 56),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _completeSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
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
