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

class SetupGate extends ConsumerWidget {
  final Widget child;
  const SetupGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final clinic = ref.watch(clinicSettingsProvider);

    // Wait for data to load
    if (user.clinicId.isEmpty || clinic.id.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!user.setupComplete || !clinic.setupComplete) {
      return ClinicSetupScreen();
    }

    return child;
  }
}
