import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_module.dart';
import '../models/clinic_settings.dart';
import '../theme/app_theme.dart';
import '../services/supabase_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

// =============================================
// AUTH / CURRENT USER
// =============================================
final currentUserProvider = NotifierProvider<CurrentUserNotifier, AppUser>(
  () => CurrentUserNotifier(),
);

class CurrentUserNotifier extends Notifier<AppUser> {
  StreamSubscription? _sub;

  @override
  AppUser build() {
    final authUser = Supabase.instance.client.auth.currentUser;
    _sub?.cancel();

    if (authUser != null) {
      _fetchUser(authUser.id);

      _sub = Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (data.isNotEmpty &&
                Supabase.instance.client.auth.currentUser?.id == authUser.id) {
              // Local filtering to avoid PostgREST cache issues with .eq() on stream occasionally
              final row = data.firstWhere((r) => r['id'] == authUser.id, orElse: () => {});
              if (row.isNotEmpty) state = _mapToAppUser(row);
            }
          });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });
    return AppUser(
      id: authUser?.id ?? '',
      clinicId: '',
      name: 'Loading...',
      firstName: 'Loading',
      lastName: '',
      role: UserRole.therapist,
      userColor: Colors.purple,
      email: authUser?.email ?? '',
      phone: '',
      address: '',
      associations: const [],
      qualifications: '',
      notes: '',
      setupComplete: true, // assume true until loaded to avoid flash
    );
  }

  Future<void> _fetchUser(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        state = _mapToAppUser(data);
      } else {
        // User record doesn't exist or RLS blocked it
        debugPrint('TRESSIA DEBUG: _fetchUser returned null for userId=$userId');
      }
    } catch (e) {
      debugPrint('TRESSIA DEBUG: _fetchUser error: $e');
    }
  }

  void setUser(AppUser u) => state = u;

  Future<void> completeSetup() async {
    await Supabase.instance.client
        .from('users')
        .update({'setup_complete': true}).eq('id', state.id);
  }
}

final systemUsersProvider = NotifierProvider<SystemUsersNotifier, List<AppUser>>(
  () => SystemUsersNotifier(),
);

class SystemUsersNotifier extends Notifier<List<AppUser>> {
  StreamSubscription? _sub;

  @override
  List<AppUser> build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      _sub = Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .listen((dataList) {
            if (ref.read(currentUserProvider).clinicId == user.clinicId) {
              final filtered = dataList.where((r) => r['clinic_id'] == user.clinicId).toList();
              state = filtered.map(_mapToAppUser).toList();
            }
          });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  final _repo = SupabaseRepository();

  Future<void> addUser(AppUser u) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser.clinicId.isEmpty) return;
    try {
      final link = await _repo.inviteUser(
        email: u.email,
        role: u.role.name,
        clinicId: currentUser.clinicId,
        fullName: u.name,
      );
      
      if (link != null) {
        ref.read(invitesProvider.notifier).updateInviteLink(u.email, link);
      }
      
      // Still invalidate to ensure full sync with DB
      ref.invalidate(invitesProvider);
    } catch (e) {
      debugPrint('SystemUsersNotifier.addUser Error: $e');
      rethrow;
    }
  }

  Future<void> updateUser(AppUser u) async {
    // Current user can update their profile via auth/users table
    // For other users, usually restricted by RLS
  }

  Future<void> removeUser(String id) async {
    try {
      await _repo.deleteUser(id);
    } catch (e) {
      debugPrint('SystemUsersNotifier.removeUser Error: $e');
      rethrow;
    }
  }
}

// =============================================
// INVITES
// =============================================
final invitesProvider = NotifierProvider<InvitesNotifier, List<UserInvite>>(
  () => InvitesNotifier(),
);

class InvitesNotifier extends Notifier<List<UserInvite>> {
  final _repo = SupabaseRepository();
  StreamSubscription? _sub;

  @override
  List<UserInvite> build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      _sub = _repo.streamInvites(user.clinicId).listen((data) {
        if (ref.read(currentUserProvider).clinicId == user.clinicId) {
          state = data;
        }
      });
    }

    ref.onDispose(() => _sub?.cancel());
    return [];
  }

  Future<void> cancelInvite(String id) async {
    final oldState = state;
    state = state.where((item) => item.id != id).toList();
    try {
      await _repo.deleteInvite(id);
    } catch (e) {
      state = oldState;
      debugPrint('InvitesNotifier.cancelInvite Error: $e');
      rethrow;
    }
  }

  void updateInviteLink(String email, String link) {
    state = state.map((i) {
      if (i.email.toLowerCase() == email.toLowerCase()) {
        return i.copyWith(actionLink: link);
      }
      return i;
    }).toList();
  }

  Future<void> regenerateInvite(UserInvite invite) async {
    try {
      final newLink = await _repo.inviteUser(
        email: invite.email,
        role: invite.role,
        clinicId: invite.clinicId,
        fullName: invite.fullName,
      );
      if (newLink != null) {
        state = state
            .map((i) => i.id == invite.id ? i.copyWith(actionLink: newLink) : i)
            .toList();
      }
    } catch (e) {
      debugPrint('InvitesNotifier.regenerateInvite Error: $e');
      rethrow;
    }
  }
}

AppUser _mapToAppUser(Map<String, dynamic> data) {
  String name = data['full_name'] ?? 'Unknown User';
  List<String> parts = name.split(' ');
  String first = parts.isNotEmpty ? parts.first : '';
  String last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  UserRole role = UserRole.therapist;
  final roleStr = (data['role'] ?? '').toString().toLowerCase();
  if (roleStr == 'administrator') role = UserRole.administrator;
  else if (roleStr == 'admin') role = UserRole.admin;
  else role = UserRole.therapist;

  // Parse color from hex string, default to purple
  Color userColor = Colors.purple;
  if (data['user_color'] != null && data['user_color'].toString().isNotEmpty) {
    try {
      final hex = data['user_color'].toString().replaceFirst('#', '');
      userColor = Color(int.parse(hex, radix: 16));
    } catch (_) {}
  }

  // Parse associations
  List<UserAssociation> assocList = [];
  if (data['associations'] != null && data['associations'] is List) {
    try {
      assocList = (data['associations'] as List)
          .map((item) => UserAssociation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  return AppUser(
    id: data['id'],
    clinicId: data['clinic_id'] ?? '',
    name: name,
    firstName: first,
    lastName: last,
    role: role,
    userColor: userColor,
    email: data['email'] ?? '',
    phone: data['phone'] ?? '',
    address: data['address'] ?? '',
    base64Photo: data['photo'] ?? '',
    associations: assocList,
    qualifications: data['qualifications'] ?? '',
    notes: data['notes'] ?? '',
    setupComplete: data['setup_complete'] ?? false,
  );
}

// =============================================
// CLINIC CONFIG
// =============================================
final clinicSettingsProvider =
    NotifierProvider<ClinicSettingsNotifier, ClinicSettings>(
  () => ClinicSettingsNotifier(),
);

class ClinicSettingsNotifier extends Notifier<ClinicSettings> {
  StreamSubscription? _sub;

  @override
  ClinicSettings build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      _fetchClinic(user.clinicId);

      _sub = Supabase.instance.client
          .from('clinics')
          .stream(primaryKey: ['id'])
          .eq('id', user.clinicId)
          .listen((data) {
            if (data.isNotEmpty &&
                ref.read(currentUserProvider).clinicId == user.clinicId) {
              final row = data.first;
              state = _mapToClinicSettings(row);
            }
          });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });
    return ClinicSettings(
      id: user.clinicId,
      clinicName: 'Loading...',
      setupComplete: true, // Assume true until loaded to avoid flash
    );
  }

  Future<void> _fetchClinic(String clinicId) async {
    try {
      final data = await Supabase.instance.client
          .from('clinics')
          .select()
          .eq('id', clinicId)
          .maybeSingle();
      if (data != null) {
        state = _mapToClinicSettings(data);
      }
    } catch (_) {
      // Stream will catch up
    }
  }


  Future<void> updateSettings(ClinicSettings s) async {
    await Supabase.instance.client.from('clinics').update({
      'name': s.clinicName,
      'description': s.description,
      'address': s.address,
      'phone': s.phone,
      'email': s.email,
      'setup_complete': s.setupComplete,
    }).eq('id', s.id);
  }

  Future<void> completeClinicSetup() async {
    await Supabase.instance.client
        .from('clinics')
        .update({'setup_complete': true}).eq('id', state.id);
  }
}

ClinicSettings _mapToClinicSettings(Map<String, dynamic> data) {
  return ClinicSettings(
    id: data['id'],
    clinicName: data['name'] ?? '',
    description: data['description'] ?? '',
    address: data['address'] ?? '',
    phone: data['phone'] ?? '',
    email: data['email'] ?? '',
    base64Logo: data['logo'] ?? '',
    setupComplete: data['setup_complete'] ?? false,
  );
}

// =============================================
// CLIENT TYPES
// =============================================
final clientTypesProvider = NotifierProvider<ClientTypesNotifier, List<String>>(
  () => ClientTypesNotifier(),
);

class ClientTypesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['Private', 'NDIS', 'Medicare', 'WorkCover', 'Internal Project'];
  void addType(String t) => state = [...state, t];
}

// =============================================
// THEME
// =============================================
final themeModeProvider = NotifierProvider<ThemeModeNotifier, UIMode>(
  () => ThemeModeNotifier(),
);

class ThemeModeNotifier extends Notifier<UIMode> {
  @override
  UIMode build() => UIMode.light;
  void toggle() => state = state == UIMode.dark ? UIMode.light : UIMode.dark;
}

// =============================================
// PROJECTS / CLIENTS
// =============================================
final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(
  () => ProjectsNotifier(),
);

class ProjectsNotifier extends Notifier<List<Project>> {
  final _repo = SupabaseRepository();
  StreamSubscription? _sub;
  DateTime _suppressStreamUntil = DateTime(0);

  void _suppressStream() {
    _suppressStreamUntil = DateTime.now().add(const Duration(seconds: 3));
  }

  @override
  List<Project> build() {
    final user = ref.watch(currentUserProvider);
    
    // Always clean up existing subscription on rebuild
    _sub?.cancel();
    
    if (user.clinicId.isNotEmpty) {
      // Initial background fetch
      _repo.fetchProjects(user.clinicId).then((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        state = data;
      });

      _sub = _repo.streamProjects(user.clinicId).listen((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        if (ref.read(currentUserProvider).clinicId == user.clinicId) {
          state = data;
        }
      });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  Future<void> addProject(Project p) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    state = [...state, p];
    
    try {
      await _repo.saveProject(p, clinicId);
    } catch (e) {
      state = state.where((item) => item.id != p.id).toList();
      rethrow;
    }
  }

  Future<void> updateProject(Project p) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    final oldState = state;
    state = [for (final item in state) if (item.id == p.id) p else item];
    
    try {
      await _repo.saveProject(p, clinicId);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  Future<void> removeProject(String id) async {
    _suppressStream();
    final oldState = state;
    state = state.where((item) => item.id != id).toList();
    
    try {
      await _repo.deleteProject(id);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }
}

// =============================================
// SESSIONS
// =============================================
final sessionsProvider = NotifierProvider<SessionsNotifier, List<Session>>(
  () => SessionsNotifier(),
);

class SessionsNotifier extends Notifier<List<Session>> {
  final _repo = SupabaseRepository();
  StreamSubscription? _sub;

  @override
  List<Session> build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      // Initial fetch
      _repo.fetchSessions(user.clinicId).then((data) => state = data);

      _sub = _repo.streamSessions(user.clinicId).listen((data) {
        if (ref.read(currentUserProvider).clinicId == user.clinicId) {
          state = data;
        }
      });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  Future<void> addSession(Session s) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    state = [...state, s];
    try {
      await _repo.saveSession(s, clinicId);
    } catch (e) {
      state = state.where((item) => item.id != s.id).toList();
      rethrow;
    }
  }

  Future<void> updateSession(Session s) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    final oldState = state;
    state = [for (final item in state) if (item.id == s.id) s else item];
    try {
      await _repo.saveSession(s, clinicId);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  Future<void> removeSession(String id) async {
    final oldState = state;
    state = state.where((item) => item.id != id).toList();
    try {
      await _repo.deleteSession(id);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  List<Session> forClient(String clientId) =>
      state.where((s) => s.clientId == clientId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
}

// =============================================
// TASKS
// =============================================
final tasksProvider = NotifierProvider<TasksNotifier, List<ProjectTask>>(
  () => TasksNotifier(),
);

class TasksNotifier extends Notifier<List<ProjectTask>> {
  final _repo = SupabaseRepository();
  StreamSubscription? _sub;
  DateTime _suppressStreamUntil = DateTime(0);

  void _suppressStream() {
    _suppressStreamUntil = DateTime.now().add(const Duration(seconds: 3));
  }

  @override
  List<ProjectTask> build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      _repo.fetchTasks(user.clinicId).then((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        state = data;
      });

      _sub = _repo.streamTasks(user.clinicId).listen((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        if (ref.read(currentUserProvider).clinicId == user.clinicId) {
          state = data;
        }
      });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  Future<void> addTask(ProjectTask t) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    state = [...state, t];
    
    try {
      await _repo.saveTask(t, clinicId);
    } catch (e) {
      state = state.where((item) => item.id != t.id).toList();
      rethrow;
    }
  }

  Future<void> updateTask(ProjectTask t) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    final oldState = state;
    state = [for (final item in state) if (item.id == t.id) t else item];
    
    try {
      await _repo.saveTask(t, clinicId);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  Future<void> removeTask(String id) async {
    _suppressStream();
    final oldState = state;
    state = state.where((item) => item.id != id).toList();
    
    try {
      await _repo.deleteTask(id);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }
}

// =============================================
// SUBTASKS
// =============================================
final subtasksProvider = NotifierProvider<SubtasksNotifier, List<Subtask>>(
  () => SubtasksNotifier(),
);

class SubtasksNotifier extends Notifier<List<Subtask>> {
  final _repo = SupabaseRepository();
  StreamSubscription? _sub;
  DateTime _suppressStreamUntil = DateTime(0);

  void _suppressStream() {
    _suppressStreamUntil = DateTime.now().add(const Duration(seconds: 3));
  }

  @override
  List<Subtask> build() {
    final user = ref.watch(currentUserProvider);
    _sub?.cancel();

    if (user.clinicId.isNotEmpty) {
      _repo.fetchSubtasks(user.clinicId).then((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        state = data;
      });

      _sub = _repo.streamSubtasks(user.clinicId).listen((data) {
        if (DateTime.now().isBefore(_suppressStreamUntil)) return;
        if (ref.read(currentUserProvider).clinicId == user.clinicId) {
          state = data;
        }
      });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  Future<void> addSubtask(Subtask s) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    state = [...state, s];
    
    try {
      await _repo.saveSubtask(s, clinicId);
    } catch (e) {
      state = state.where((item) => item.id != s.id).toList();
      rethrow;
    }
  }

  Future<void> updateSubtask(Subtask s) async {
    final clinicId = ref.read(currentUserProvider).clinicId;
    if (clinicId.isEmpty) return;
    
    _suppressStream();
    final oldState = state;
    state = [for (final item in state) if (item.id == s.id) s else item];
    
    try {
      await _repo.saveSubtask(s, clinicId);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }

  Future<void> removeSubtask(String id) async {
    _suppressStream();
    final oldState = state;
    state = state.where((item) => item.id != id).toList();
    
    try {
      await _repo.deleteSubtask(id);
    } catch (e) {
      state = oldState;
      rethrow;
    }
  }
}

// =============================================
// NDIS PROVIDERS
// =============================================
final providersProvider =
    NotifierProvider<ProvidersNotifier, List<NdisProvider>>(
      () => ProvidersNotifier(),
    );

class ProvidersNotifier extends Notifier<List<NdisProvider>> {
  @override
  List<NdisProvider> build() => [
    NdisProvider(
      id: 'prov1',
      businessName: 'Northern NSW Plan Management',
      type: ProviderType.ndis,
      contactName: 'Sarah Smith',
      phone: '02 6622 9999',
      email: 'admin@nnswpm.com.au',
      address: '88 Main Street, Lismore NSW 2480',
      notes: 'Preferred plan manager for NDIS clients.',
      associatedClientIds: ['p1'],
    ),
    NdisProvider(
      id: 'prov2',
      businessName: 'Sunrise Support Coordination',
      type: ProviderType.ndis,
      contactName: 'Tom Johnson',
      phone: '0400 111 222',
      email: 'tom@sunrisecoords.com.au',
      address: 'Unit 4, 22 Conway Street, Ballina NSW 2478',
      notes: 'Specialist support coordinator.',
      associatedClientIds: ['p1'],
    ),
    NdisProvider(
      id: 'prov3',
      businessName: 'Lismore Base Hospital — CMH',
      type: ProviderType.specialist,
      contactName: 'Dr. Amy Patel',
      phone: '02 6620 3000',
      email: 'a.patel@lnhs.gov.au',
      address: '60 Uralba Street, Lismore NSW 2480',
      notes: 'Community Mental Health team.',
      associatedClientIds: ['p1'],
    ),
  ];

  void addProvider(NdisProvider p) => state = [...state, p];
  void updateProvider(NdisProvider p) => state = [
    for (final x in state)
      if (x.id == p.id) p else x,
  ];
  void removeProvider(String id) =>
      state = state.where((p) => p.id != id).toList();
}

// =============================================
// ASSIGNMENT REQUESTS
// =============================================
final assignmentRequestsProvider =
    NotifierProvider<AssignmentRequestsNotifier, List<AssignmentRequest>>(
      () => AssignmentRequestsNotifier(),
    );

class AssignmentRequestsNotifier extends Notifier<List<AssignmentRequest>> {
  @override
  List<AssignmentRequest> build() => [];
  void addRequest(AssignmentRequest r) => state = [...state, r];
  void updateRequest(String id, AssignmentRequestStatus status) => state = [
    for (final r in state)
      if (r.id == id)
        AssignmentRequest(
          id: r.id,
          fromUserId: r.fromUserId,
          toUserId: r.toUserId,
          entityType: r.entityType,
          entityId: r.entityId,
          entityTitle: r.entityTitle,
          message: r.message,
          status: status,
          createdAt: r.createdAt,
        )
      else
        r,
  ];
}

// =============================================
// ALERTS — derived provider
// =============================================
final alertsProvider = Provider<List<String>>((ref) {
  final subs = ref.watch(subtasksProvider);
  final sessions = ref.watch(sessionsProvider);
  final requests = ref.watch(assignmentRequestsProvider);
  final now = DateTime.now();
  List<String> alerts = [];

  for (var s in subs) {
    if (s.status != TaskStatus.done && s.endDate.isBefore(now)) {
      alerts.add('OVERDUE: ${s.title}');
    }
  }
  for (var sess in sessions) {
    if (sess.status == SessionStatus.scheduled &&
        sess.date.isBefore(now.add(const Duration(hours: 24))) &&
        sess.date.isAfter(now)) {
      alerts.add('Session tomorrow: ${sess.date.day}/${sess.date.month}');
    }
  }
  for (var r in requests) {
    if (r.status == AssignmentRequestStatus.pending) {
      alerts.add('Assignment request: ${r.entityTitle}');
    }
  }
  return alerts;
});

// =============================================
// TODAY'S SCHEDULE — derived provider
// =============================================
final todayScheduleProvider = Provider<List<dynamic>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final tasks = ref.watch(tasksProvider);
  final subtasks = ref.watch(subtasksProvider);
  final sessions = ref.watch(sessionsProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  List<dynamic> items = [];

  // Sessions today for this user
  for (var s in sessions) {
    if (s.therapistIds.contains(currentUser.id) &&
        s.date.isAfter(todayStart.subtract(const Duration(hours: 1))) &&
        s.date.isBefore(todayEnd) &&
        s.status != SessionStatus.cancelled) {
      items.add(s);
    }
  }

  // Tasks/subtasks spanning today for this user
  for (var t in tasks) {
    if (t.assignedUserIds.contains(currentUser.id) &&
        t.startDate.isBefore(todayEnd) &&
        t.endDate.isAfter(todayStart) &&
        t.status != TaskStatus.done) {
      items.add(t);
    }
  }
  for (var s in subtasks) {
    if (s.assignedUserIds.contains(currentUser.id) &&
        s.startDate.isBefore(todayEnd) &&
        s.endDate.isAfter(todayStart) &&
        s.status != TaskStatus.done) {
      items.add(s);
    }
  }

  return items;
});
