import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_module.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/glass_dialog.dart';
import '../widgets/dialogs/client_creator.dart';
import 'client_profile_screen.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({Key? key}) : super(key: key);
  @override
  _ClientsListScreenState createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final allProjects = ref.watch(projectsProvider);
    final sessions = ref.watch(sessionsProvider);
    final users = ref.watch(systemUsersProvider);

    // Role-filtered: Admin sees all, therapist sees only assigned
    final projects = currentUser.isAdmin
        ? allProjects
        : allProjects
              .where((p) => p.assignedTherapistIds.contains(currentUser.id))
              .toList();

    final filtered = projects.where((p) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return p.clientName.toLowerCase().contains(q) ||
          p.clientCode.toLowerCase().contains(q) ||
          p.clientType.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Clients',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'New Client',
            onPressed: () =>
                showGlassDialog(context, const ClientCreatorDialog()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Count chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} client${filtered.length != 1 ? 's' : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
                const Spacer(),
                if (!currentUser.isAdmin)
                  Text(
                    'Showing your clients only',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          // Client list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: theme.hintColor.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No clients found',
                          style: GoogleFonts.outfit(color: theme.hintColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final clientSessions = sessions
                          .where((s) => s.clientId == p.id)
                          .toList();
                      final nextSession =
                          clientSessions
                              .where(
                                (s) =>
                                    s.status == SessionStatus.scheduled &&
                                    s.date.isAfter(DateTime.now()),
                              )
                              .toList()
                            ..sort((a, b) => a.date.compareTo(b.date));
                      final therapist = users.firstWhere(
                        (u) => p.assignedTherapistIds.contains(u.id),
                        orElse: () => users.first,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClientProfileScreen(clientProject: p),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: theme.primaryColor
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    p.firstName.isNotEmpty
                                        ? p.firstName[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.clientName,
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _typeColor(
                                                p.clientType,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.clientType,
                                              style: GoogleFonts.outfit(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: _typeColor(p.clientType),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            p.clientCode,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${therapist.displayName}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: theme.hintColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      if (nextSession.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.event,
                                              size: 12,
                                              color: theme.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Next: ${nextSession.first.date.day}/${nextSession.first.date.month}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '${clientSessions.length}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.hintColor.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'NDIS':
        return Colors.blue;
      case 'Medicare':
        return Colors.green;
      case 'Private':
        return Colors.purple;
      case 'WorkCover':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
