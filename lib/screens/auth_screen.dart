import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        // Sign up logic
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        // Sign in logic
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // On success, the StreamBuilder in main.dart handles the routing!
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred: e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Tressia standard brand green for buttons
    final brandGreen = const Color(0xFF2E7D32); // Deep rich green
    
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
                color: isDark ? const Color(0xFF161816) : const Color(0xFFFBF8F1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    // Inner glowing shadow logic similar to Kanban tiles
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
                  // App Title / Brand
                  Text(
                    'Tressia',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Therapeutic Dashboard',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: theme.hintColor,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(color: Colors.red[400], fontSize: 13),
                      ),
                    ),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: GoogleFonts.outfit(color: theme.hintColor),
                      prefixIcon: Icon(Icons.email_outlined, color: theme.hintColor),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: brandGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.outfit(color: theme.hintColor),
                      prefixIcon: Icon(Icons.lock_outline, color: theme.hintColor),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: brandGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login / Sign Up Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'REGISTER' : 'LOG IN',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle mode
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.hintColor,
                    ),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Log in'
                          : 'Need provider access? Sign up',
                      style: GoogleFonts.outfit(fontSize: 13),
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
