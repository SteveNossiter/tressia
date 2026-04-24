import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _setupPassword() async {
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. First properly set the password natively with Supabase Auth
      // We do NOT clear needs_password_setup yet, so the screen stays locked on this view
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      // 2. Trigger Edge Function to process invite -> user transfer
      final String jwt = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final res = await Supabase.instance.client.functions.invoke(
        'accept-invite',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.status != 200) {
        throw Exception('Failed to finalize server-side account: ${res.data}');
      }

      // 3. WAIT SCREEN: Poll the database until the public.users record is active
      // This prevents the "blank screen" or "profile not found" error during cloud sync
      bool userCreated = false;
      int attempts = 0;
      final userId = Supabase.instance.client.auth.currentUser?.id;

      while (!userCreated && attempts < 10) {
        attempts++;
        final check = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('id', userId ?? '')
            .maybeSingle();
        
        if (check != null) {
          userCreated = true;
          break;
        }
        // Wait 2 seconds before retrying
        await Future.delayed(const Duration(seconds: 2));
      }

      if (!userCreated) {
        throw Exception('Server sync is taking longer than expected. Please try again in 1 minute.');
      }

      // 4. FINAL HANDSHAKE: Clear the setup flag now that the DB is ready
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'needs_password_setup': false}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully activated! Welcome to Tressia.')),
        );
      }

    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandGreen = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF161816) : const Color(0xFFFBF8F1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_person_outlined, size: 64, color: brandGreen),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Tressia',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please set a password to secure your account and complete your registration.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 14, color: theme.hintColor),
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.red[400], fontSize: 13)),
                    ),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: GoogleFonts.outfit(),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    style: GoogleFonts.outfit(),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _setupPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'FINALISING YOUR ACCOUNT...',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            )
                          : Text('SAVE PASSWORD', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
