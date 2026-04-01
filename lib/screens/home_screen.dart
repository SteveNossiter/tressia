import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/clinic_settings.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'providers_screen.dart';
import 'users_screen.dart';
import 'clients_list_screen.dart';
import '../widgets/block_calendar.dart';
import '../widgets/raimble_record_button.dart';
import 'clinic_details_screen.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../widgets/dialogs/client_creator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  List<(IconData, String)> _navItems(bool isAdmin) => [
    (Icons.dashboard_outlined, 'Board'),
    (Icons.calendar_month_outlined, 'Calendar'),
    (Icons.people_outlined, 'Clients'),
    (Icons.business_outlined, 'Providers'),
    if (isAdmin) (Icons.group_outlined, 'Users'),
    (Icons.apartment_rounded, 'Clinic'),
  ];

  List<Widget> _pages(bool isAdmin) => [
    const DashboardScreen(),
    BlockCalendar(tasks: ref.watch(tasksProvider)),
    const ClientsListScreen(),
    const ProvidersScreen(),
    if (isAdmin) const UsersScreen(),
    const ClinicDetailsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.isAdmin;
    final navItems = _navItems(isAdmin);
    final pages = _pages(isAdmin);

    // Clamp index if nav items changed due to role switch
    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.colorScheme.secondary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            Text(
              'Tressia',
              style: GoogleFonts.lora(
                fontWeight: FontWeight.w600,
                fontSize: 19,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 12),
            // Trial Version Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'TRIAL',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _buildNotificationIcon(),
          _buildUserMenu(theme, currentUser),
          _buildThemeToggle(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGlassDialog(context, const ClientCreatorDialog()),
        icon: const Icon(Icons.person_add),
        label: Text(
          'New Client',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (val) =>
                      setState(() => _selectedIndex = val),
                  labelType: NavigationRailLabelType.all,
                  useIndicator: true,
                  destinations: navItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.$1),
                          label: Text(
                            item.$2,
                            style: GoogleFonts.outfit(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                  trailing: const Expanded(child: SizedBox.shrink()),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: pages[_selectedIndex]),
              ],
            )
          : pages[_selectedIndex],
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (v) => setState(() => _selectedIndex = v),
              destinations: navItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.$1),
                      label: item.$2,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer(
      builder: (context, ref, child) {
        final alerts = ref.watch(alertsProvider);
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.notifications, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Alerts',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  content: alerts.isEmpty
                      ? Text(
                          'No active alerts.',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).hintColor,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: alerts
                              .map(
                                (a) => ListTile(
                                  leading: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    a,
                                    style: GoogleFonts.outfit(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            ),
            if (alerts.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // User menu with profile pic, name, logout, edit profile
  Widget _buildUserMenu(ThemeData theme, AppUser user) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      onSelected: (val) async {
        if (val == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
          );
        } else if (val == 'logout') {
          await Supabase.instance.client.auth.signOut();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Text('Edit Profile', style: GoogleFonts.outfit()),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text('Logout', style: GoogleFonts.outfit(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: user.userColor.withValues(alpha: 0.2),
              child: Text(
                user.initials,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: user.userColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                user.displayName,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Consumer(
      builder: (ctx, ref, child) {
        final mode = ref.watch(themeModeProvider);
        return IconButton(
          tooltip: 'Toggle theme',
          icon: Icon(mode == UIMode.dark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        );
      },
    );
  }
}
