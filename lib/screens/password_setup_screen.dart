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
      // 1. First properly confirm password change natively with Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: {'needs_password_setup': false},
        ),
      );

      // 2. Safely trigger Edge Function to process invite -> user transfer securely across servers!
      final String jwt = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final res = await Supabase.instance.client.functions.invoke(
        'accept-invite',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.status != 200) {
        throw Exception('Failed to migrate invite credentials: ${res.data}');
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
                          ? const CircularProgressIndicator(color: Colors.white)
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
