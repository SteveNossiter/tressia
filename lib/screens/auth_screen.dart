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
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _showVerificationMessage = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        // Validation for registration
        if (_nameController.text.trim().isEmpty) {
          throw Exception('Please enter your full name');
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }
        if (_passwordController.text.length < 6) {
          throw Exception('Password must be at least 6 characters');
        }

        // Sign up logic with user metadata
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'full_name': _nameController.text.trim(),
          },
        );
        
        // If email confirmation is enabled, session might be null or user.emailConfirmedAt will be null
        if (mounted) {
          setState(() {
            _showVerificationMessage = true;
          });
        }
      } else {
        // Sign in logic
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
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
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                color: isDark ? const Color(0xFF161816) : const Color(0xFFFBF8F1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _showVerificationMessage 
                  ? _buildVerificationView(theme, brandGreen)
                  : _buildAuthForm(theme, brandGreen, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationView(ThemeData theme, Color brandGreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 64, color: brandGreen),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'We have sent a verification link to ${_emailController.text.trim()}. Please confirm your email to activate your account.',
          style: GoogleFonts.outfit(fontSize: 14, color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showVerificationMessage = false;
                _isSignUp = false;
                _passwordController.clear();
                _confirmPasswordController.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('BACK TO LOG IN', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm(ThemeData theme, Color brandGreen, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tressia',
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Therapeutic Dashboard',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, color: theme.hintColor, letterSpacing: 1.5),
        ),
        const SizedBox(height: 40),

        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.red[400], fontSize: 13)),
          ),

        if (_isSignUp) ...[
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
            decoration: _inputDecoration(theme, 'Full Name', Icons.person_outline, brandGreen, isDark),
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
          decoration: _inputDecoration(theme, 'Email Address', Icons.email_outlined, brandGreen, isDark),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
          decoration: _inputDecoration(
            theme, 
            'Password', 
            Icons.lock_outline, 
            brandGreen, 
            isDark,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: theme.hintColor, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        
        if (_isSignUp) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
            decoration: _inputDecoration(
              theme, 
              'Confirm Password', 
              Icons.lock_reset, 
              brandGreen, 
              isDark,
              suffix: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: theme.hintColor, size: 20),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isSignUp ? 'REGISTER' : 'LOG IN', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            setState(() {
              _isSignUp = !_isSignUp;
              _errorMessage = null;
            });
          },
          child: Text(
            _isSignUp ? 'Already have an account? Log in' : 'Need provider access? Sign up',
            style: GoogleFonts.outfit(fontSize: 13, color: theme.hintColor),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ThemeData theme, String label, IconData icon, Color brandGreen, bool isDark, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: theme.hintColor),
      prefixIcon: Icon(icon, color: theme.hintColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: brandGreen),
      ),
    );
  }
}
