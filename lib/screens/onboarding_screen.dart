import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../models/clinic_settings.dart';
import '../services/supabase_repository.dart';
import '../theme/organic_palette.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isLoading = false;
  List<UserAssociation> _userAssociations = [];
  Color _selectedColor = Colors.purple;

  late TextEditingController _passwordCtrl, _confirmPasswordCtrl;
  late TextEditingController _userFirstNameCtrl, _userLastNameCtrl, _userPhoneCtrl, _userAddressCtrl, _userEmailCtrl;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _userFirstNameCtrl = TextEditingController();
    _userLastNameCtrl = TextEditingController();
    _userPhoneCtrl = TextEditingController();
    _userAddressCtrl = TextEditingController();
    _userEmailCtrl = TextEditingController();

    // Initial population
    _populateFields();
  }

  void _populateFields() {
    final user = ref.read(currentUserProvider);
    if (user.id.isEmpty && user.email.isEmpty) return; // Still loading

    _userFirstNameCtrl.text = user.firstName;
    _userLastNameCtrl.text = user.lastName;
    _userPhoneCtrl.text = user.phone;
    _userAddressCtrl.text = user.address;
    _userEmailCtrl.text = user.email;
    
    setState(() {
      _userAssociations = user.associations.isEmpty 
          ? [UserAssociation(name: 'ANZACATA', membershipNumber: '')]
          : List.from(user.associations);
      _selectedColor = user.userColor;
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _userFirstNameCtrl.dispose();
    _userLastNameCtrl.dispose();
    _userPhoneCtrl.dispose();
    _userAddressCtrl.dispose();
    _userEmailCtrl.dispose();
    super.dispose();
  }


  Future<void> _completeSetup() async {
    // Basic Validation
    if (_userFirstNameCtrl.text.isEmpty) {
      _error('Please enter your first name.');
      return;
    }

    final hasPassword = _passwordCtrl.text.isNotEmpty;
    if (hasPassword) {
      if (_passwordCtrl.text.length < 6) {
        _error('Password must be at least 6 characters.');
        return;
      }
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        _error('Passwords do not match.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = SupabaseRepository();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // 1. Update Password (if provided)
      if (hasPassword) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _passwordCtrl.text),
        );
      }

      // 2. Formalise invitation migration (Server-side switch from invites -> users)
      // This function handles creating the row in public.users if it doesn't exist
      await repo.acceptInvite();

      // 3. Save Profile Details to our new public.users row
      final hexColor = '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      
      await Supabase.instance.client.from('users').update({
        'full_name': '${_userFirstNameCtrl.text} ${_userLastNameCtrl.text}'.trim(),
        'first_name': _userFirstNameCtrl.text.trim(),
        'last_name': _userLastNameCtrl.text.trim(),
        'phone': _userPhoneCtrl.text.trim(),
        'address': _userAddressCtrl.text.trim(),
        'email': _userEmailCtrl.text.trim(),
        'user_color': hexColor,
        'associations': _userAssociations.map((e) => e.toJson()).toList(),
        'setup_complete': true,
      }).eq('id', userId ?? '');

      // 4. Cleanup Auth Metadata (if we used any flags)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'needs_password_setup': false}),
      );

      // 5. Force refresh
      ref.invalidate(currentUserProvider);
      ref.invalidate(clinicSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome aboard! Your profile is ready.')),
        );
      }
    } catch (e) {
      _error('Error completing setup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _error(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen for data arriving after initialization (Riverpod 2 style)
    ref.listen(currentUserProvider, (prev, next) {
      if (next.firstName.isNotEmpty && _userFirstNameCtrl.text.isEmpty) {
        _populateFields();
      }
    });
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                pinned: true,
                title: Text(
                  'Complete Your Profile',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.red)),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _instruction('Welcome to the team! Please finalize your account details to get started.'),
                          const SizedBox(height: 32),

                          // 1. PASSWORD
                          _subHeader(theme, 'Secure Your Account'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _field('New Password', _passwordCtrl, isPass: true, icon: Icons.lock_outline),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _field('Confirm Password', _confirmPasswordCtrl, isPass: true, icon: Icons.lock_reset),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // 2. IDENTITY
                          _subHeader(theme, 'Personal Identity'),
                          const SizedBox(height: 16),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: _field('First Name', _userFirstNameCtrl)),
                              const SizedBox(width: 16),
                              Expanded(child: _field('Last Name', _userLastNameCtrl)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _field('Public Email', _userEmailCtrl, enabled: false),
                          const SizedBox(height: 12),
                          _field('Public Phone', _userPhoneCtrl),
                          
                          const SizedBox(height: 24),
                          Text('Select Your Signature Colour', style: GoogleFonts.outfit(fontSize: 13, color: theme.hintColor)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: OrganicPalette.colors.map((c) => GestureDetector(
                              onTap: () => setState(() => _selectedColor = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: _selectedColor == c ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                                ),
                                child: _selectedColor == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                              ),
                            )).toList(),
                          ),
                          
                          const SizedBox(height: 40),

                          // 3. ASSOCIATIONS
                          _subHeader(theme, 'Professional Associations'),
                          const SizedBox(height: 16),
                          ..._userAssociations.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final assoc = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: ['ANZACATA', 'PACFA', 'ACA', 'Other'].contains(assoc.name) ? assoc.name : 'Other',
                                      decoration: _inputDec('Association'),
                                      items: ['ANZACATA', 'PACFA', 'ACA', 'Other']
                                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.outfit(fontSize: 14))))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _userAssociations[idx] = UserAssociation(name: v, membershipNumber: assoc.membershipNumber));
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 4,
                                    child: TextField(
                                      decoration: _inputDec('Membership #'),
                                      controller: TextEditingController(text: assoc.membershipNumber)..selection = TextSelection.fromPosition(TextPosition(offset: assoc.membershipNumber.length)),
                                      onChanged: (v) => _userAssociations[idx] = UserAssociation(name: assoc.name, membershipNumber: v),
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
                            onPressed: () => setState(() => _userAssociations.add(UserAssociation(name: 'ANZACATA', membershipNumber: ''))),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ADD ANOTHER ASSOCIATION'),
                          ),

                          const SizedBox(height: 64),
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
                              child: Text('COMPLETE PROFILE & START', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _instruction(String t) => Text(t, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14));

  Widget _subHeader(ThemeData theme, String t) => Text(t, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor));

  Widget _field(String label, TextEditingController ctrl, {bool isPass = false, bool enabled = true, IconData? icon}) => TextField(
    controller: ctrl,
    obscureText: isPass,
    enabled: enabled,
    decoration: _inputDec(label).copyWith(
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      fillColor: enabled ? null : Colors.grey.withValues(alpha: 0.1),
    ),
  );

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
