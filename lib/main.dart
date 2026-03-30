import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/clinic_setup_screen.dart';
import 'services/encryption_service.dart';

// IMPORTANT: Supabase URL and Anon / Publishable Key
const supabaseUrl = 'https://dfwpvvppdnpyrvnoccni.supabase.co';
const supabaseAnonKey = 'sb_publishable_FTGBQ79nE2DvdSBkU4D-gQ_lV5Gj1wY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  await EncryptionService.init();
  runApp(const ProviderScope(child: TressiaApp()));
}

class TressiaApp extends ConsumerWidget {
  const TressiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Tressia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(uiMode),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Use either the stream event or the current session as fallback
        // This prevents the infinite spinner on initial web load
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final user = session?.user ??
            Supabase.instance.client.auth.currentUser;

        // Ensure email is confirmed before allowing them through
        if (session != null && user?.emailConfirmedAt != null) {
          return const SetupGate(child: HomeScreen());
        }

        return const AuthScreen();
      },
    );
  }
}

class SetupGate extends ConsumerStatefulWidget {
  final Widget child;
  const SetupGate({super.key, required this.child});

  @override
  ConsumerState<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends ConsumerState<SetupGate> {
  bool _timedOut = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _runDiagnostics();
        setState(() => _timedOut = true);
      }
    });
  }

  Future<void> _runDiagnostics() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        _debugInfo = 'No auth user found';
        return;
      }

      // Try a direct fetch to see what happens
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (response == null) {
        _debugInfo = 'Auth OK (${authUser.id}), but users table returned NULL.\n'
            'This means RLS is blocking the read or no row exists.';
      } else {
        _debugInfo = 'Data found: clinic_id=${response['clinic_id']}, '
            'role=${response['role']}';
      }
    } catch (e) {
      _debugInfo = 'Fetch error: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _retry() async {
    setState(() {
      _timedOut = false;
      _debugInfo = '';
    });
    // Force re-fetch
    ref.invalidate(currentUserProvider);
    ref.invalidate(clinicSettingsProvider);
    await Future.delayed(const Duration(seconds: 6));
    if (mounted) {
      await _runDiagnostics();
      setState(() => _timedOut = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clinic = ref.watch(clinicSettingsProvider);

    // Wait for data to load
    if (user.clinicId.isEmpty || clinic.id.isEmpty) {
      if (_timedOut) {
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load your account data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _debugInfo.isNotEmpty ? _debugInfo : 'Running diagnostics...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'userId="${user.id}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('RETRY'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => Supabase.instance.client.auth.signOut(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('LOG OUT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Data is loaded, check if setup is complete
    if (!user.setupComplete || !clinic.setupComplete) {
      return ClinicSetupScreen();
    }

    return widget.child;
  }
}

