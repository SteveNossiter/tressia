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
  @override
  AppUser build() {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null) {
      Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', authUser.id)
          .listen((data) {
            if (data.isNotEmpty &&
                Supabase.instance.client.auth.currentUser != null) {
              final row = data.first;
              state = _mapToAppUser(row);
            }
          });
    }
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
      ahpraNumber: '',
      qualifications: '',
      notes: '',
      setupComplete: true, // assume true until loaded to avoid flash
    );
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
  @override
  List<AppUser> build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('clinic_id', user.clinicId)
          .listen((dataList) {
            if (Supabase.instance.client.auth.currentUser != null) {
              state = dataList.map(_mapToAppUser).toList();
            }
          });
    }
    return [];
  }

  void addUser(AppUser u) {}
  void updateUser(AppUser u) {}
  void removeUser(String id) {}
}

AppUser _mapToAppUser(Map<String, dynamic> data) {
  String name = data['full_name'] ?? 'Unknown User';
  List<String> parts = name.split(' ');
  String first = parts.isNotEmpty ? parts.first : '';
  String last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  UserRole role = UserRole.therapist;
  if (data['role'] == 'Administrator') role = UserRole.admin;
  if (data['role'] == 'Admin') role = UserRole.receptionist;

  return AppUser(
    id: data['id'],
    clinicId: data['clinic_id'] ?? '',
    name: name,
    firstName: first,
    lastName: last,
    role: role,
    userColor: Colors.purple,
    email: '',
    phone: '',
    address: '',
    ahpraNumber: '',
    qualifications: '',
    notes: '',
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
  @override
  ClinicSettings build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      Supabase.instance.client
          .from('clinics')
          .stream(primaryKey: ['id'])
          .eq('id', user.clinicId)
          .listen((data) {
            if (data.isNotEmpty &&
                Supabase.instance.client.auth.currentUser != null) {
              final row = data.first;
              state = _mapToClinicSettings(row);
            }
          });
    }
    return ClinicSettings(
      id: user.clinicId,
      clinicName: 'Loading...',
    );
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
  List<String> build() => ['Private', 'NDIS', 'Medicare', 'WorkCover'];
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

  @override
  List<Project> build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      _repo.streamProjects(user.clinicId).listen((data) {
        if (Supabase.instance.client.auth.currentUser != null) {
          state = data;
        }
      });
    }
    return [];
  }

  void addProject(Project p) => _repo.saveProject(p, ref.read(currentUserProvider).clinicId);
  void updateProject(Project p) => _repo.saveProject(p, ref.read(currentUserProvider).clinicId);
  void removeProject(String id) => _repo.deleteProject(id);
}

// =============================================
// SESSIONS
// =============================================
final sessionsProvider = NotifierProvider<SessionsNotifier, List<Session>>(
  () => SessionsNotifier(),
);

class SessionsNotifier extends Notifier<List<Session>> {
  final _repo = SupabaseRepository();

  @override
  List<Session> build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      _repo.streamSessions(user.clinicId).listen((data) {
        if (Supabase.instance.client.auth.currentUser != null) {
          state = data;
        }
      });
    }
    return [];
  }

  void addSession(Session s) => _repo.saveSession(s, ref.read(currentUserProvider).clinicId);
  void updateSession(Session s) => _repo.saveSession(s, ref.read(currentUserProvider).clinicId);
  void removeSession(String id) => _repo.deleteSession(id);

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

  @override
  List<ProjectTask> build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      _repo.streamTasks(user.clinicId).listen((data) {
        if (Supabase.instance.client.auth.currentUser != null) {
          state = data;
        }
      });
    }
    return [];
  }

  void addTask(ProjectTask t) => _repo.saveTask(t, ref.read(currentUserProvider).clinicId);
  void updateTask(ProjectTask t) => _repo.saveTask(t, ref.read(currentUserProvider).clinicId);
  void removeTask(String id) => _repo.deleteTask(id);
}

// =============================================
// SUBTASKS
// =============================================
final subtasksProvider = NotifierProvider<SubtasksNotifier, List<Subtask>>(
  () => SubtasksNotifier(),
);

class SubtasksNotifier extends Notifier<List<Subtask>> {
  final _repo = SupabaseRepository();

  @override
  List<Subtask> build() {
    final user = ref.watch(currentUserProvider);
    if (user.clinicId.isNotEmpty) {
      _repo.streamSubtasks(user.clinicId).listen((data) {
        if (Supabase.instance.client.auth.currentUser != null) {
          state = data;
        }
      });
    }
    return [];
  }

  void addSubtask(Subtask s) => _repo.saveSubtask(s, ref.read(currentUserProvider).clinicId);
  void updateSubtask(Subtask s) => _repo.saveSubtask(s, ref.read(currentUserProvider).clinicId);
  void removeSubtask(String id) => _repo.deleteSubtask(id);
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
