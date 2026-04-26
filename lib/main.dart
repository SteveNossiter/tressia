// Trigger build rebuild — v1.0.3
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/encryption_service.dart';

// IMPORTANT: Supabase URL and Anon / Publishable Key
const supabaseUrl = 'https://dfwpvvppdnpyrvnoccni.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRmd3B2dnBwZG5weXJ2bm9jY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0ODU3NTksImV4cCI6MjA5MDA2MTc1OX0.vzZM5Hiubg9KaxBmGfFfHy6m3vYE2X8dVSndHRfkLlA';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('TRESSIA_DEBUG: App Booting...');
  
  // Use the standard implicit flow so the app can correctly digest the #access_token 
  // embedded in manually generated Edge Function invite links
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  print('TRESSIA_DEBUG: Supabase Initialised');
  
  await EncryptionService.init();
  print('TRESSIA_DEBUG: Encryption Initialised — launching UI');
  
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

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Timer? _inactivityTimer;
  bool _isProcessingInvite = false;

  @override
  void initState() {
    super.initState();
    _checkForInviteToken();
  }

  void _checkForInviteToken() {
    final fragment = Uri.base.fragment;
    if (fragment.contains('access_token=')) {
      print('TRESSIA_DEBUG: landing with access_token (invite/magiclink).');
      setState(() => _isProcessingInvite = true);
      
      // If we are already logged in as a DIFFERENT user, sign out 
      // so the new token from the URL can be digested properly.
      final currentEmail = Supabase.instance.client.auth.currentUser?.email;
      if (currentEmail != null) {
         print('TRESSIA_DEBUG: Overriding existing session for $currentEmail');
         Supabase.instance.client.auth.signOut();
      }

      // Allow 5 seconds for Supabase to digest the fragment and emit a SIGNED_IN event
      // before we show the login screen as fallback.
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isProcessingInvite = false);
      });
    }
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(hours: 2), () {
      Supabase.instance.client.auth.signOut();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessingInvite) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text('Finalising your invitation...', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          _resetTimer(); // Reset on auth state change (login)

          final session = snapshot.data?.session ??
              Supabase.instance.client.auth.currentSession;
          final user = session?.user ??
              Supabase.instance.client.auth.currentUser;

          print('TRESSIA_DEBUG: AuthGate State - session=${session != null}, userEmail=${user?.email}');
          if (user != null) {
            print('TRESSIA_DEBUG: userMetadata = ${user.userMetadata}');
          }

          if (session != null && user?.emailConfirmedAt != null) {
            // Check if they are locked in a password setup state (legacy flag)
            final needsPasswordSetup = user?.userMetadata?['needs_password_setup'] == true;
            if (needsPasswordSetup) {
              return const OnboardingScreen();
            }
            return const SetupGate(child: HomeScreen());
          }
          return const AuthScreen();
        },
      ),
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
    Future.delayed(const Duration(seconds: 8), () {
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
        _debugInfo = 'Auth OK, but users table returned NULL.\n'
            'Checking if you are a pending invitee...';
      } else {
        _debugInfo = 'Data found: role=${response['role']}';
      }
    } catch (e) {
      _debugInfo = 'Fetch error: $e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clinic = ref.watch(clinicSettingsProvider);

    // Wait for data to load
    // Note: clinicId might be empty if they are an invitee, 
    // in which case OnboardingScreen handles the migration.
    final isLoading = user.name == 'Loading...' || (user.clinicId.isNotEmpty && clinic.id.isEmpty);

    if (isLoading) {
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
                  const Text('Unable to load account data.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_debugInfo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(onPressed: () => ref.invalidate(currentUserProvider), child: const Text('RETRY')),
                      const SizedBox(width: 16),
                      ElevatedButton(onPressed: () => Supabase.instance.client.auth.signOut(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('LOG OUT')),
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
    // Direct to onboarding if setup is incomplete
    if (!user.setupComplete) {
      return const OnboardingScreen();
    }

    return widget.child;
  }
}
