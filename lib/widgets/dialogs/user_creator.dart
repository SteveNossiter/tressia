import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/clinic_settings.dart';
import '../../providers/app_state.dart';

class UserCreator extends ConsumerStatefulWidget {
  const UserCreator({Key? key}) : super(key: key);
  @override
  _UserCreatorState createState() => _UserCreatorState();
}

class _UserCreatorState extends ConsumerState<UserCreator> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  UserRole _role = UserRole.therapist;
  Color _color = Colors.blue;

  final List<Color> _palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  Future<void> _save() async {
    if (_firstCtrl.text.isEmpty || _emailCtrl.text.isEmpty) return;

    final fullName = '${_firstCtrl.text} ${_lastCtrl.text}'.trim();
    final currentUser = ref.read(currentUserProvider);

    try {
      await ref.read(systemUsersProvider.notifier).addUser(
            AppUser(
              id: '', // Will be assigned by Supabase
              clinicId: currentUser.clinicId,
              name: fullName,
              firstName: _firstCtrl.text.trim(),
              lastName: _lastCtrl.text.trim(),
              role: _role,
              userColor: _color,
              email: _emailCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              startDate: DateTime.now(),
            ),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to ${_emailCtrl.text}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inviting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Team Member',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.person_add, color: theme.primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstCtrl,
                          decoration: _dec('First Name *', theme),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastCtrl,
                          decoration: _dec('Last Name', theme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('Email Address *', theme),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec('Phone', theme),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    decoration: _dec('Role', theme),
                    value: _role,
                    items: UserRole.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _role = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Calendar Colour',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _palette
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: _color.value == c.value
                                    ? Border.all(
                                        color: theme.colorScheme.onSurface,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: _color.value == c.value
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The user will receive an email invitation to set up their password and 2FA.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Send Invite'),
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
    fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
