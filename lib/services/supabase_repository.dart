import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../models/project_module.dart';
import '../models/clinic_settings.dart';

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // PROJECTS (Clients/Phases)
  // ---------------------------------------------------------------------------
  Project _mapProject(Map<String, dynamic> data) => Project(
        id: data['id'],
        title: data['title'] ?? '',
        clientId: data['client_id'] ?? '',
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        clientCode: data['client_code'] ?? '',
        dateOfBirth: data['date_of_birth'] != null
            ? DateTime.parse(data['date_of_birth'])
            : null,
        address: data['address'] ?? '',
        phone: data['phone'] ?? '',
        email: data['email'] ?? '',
        clientType: data['client_type'] ?? 'Private',
        ndisNumber: data['ndis_number'] ?? '',
        assignedTherapistIds: (data['assigned_therapist_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        contacts: (data['contacts'] as List<dynamic>?)
                ?.map((c) => Contact(
                    firstName: c['first_name'] ?? '',
                    lastName: c['last_name'] ?? '',
                    phone: c['phone'] ?? '',
                    email: c['email'] ?? '',
                    role: c['role'] ?? '',
                    isPrimary: c['is_primary'] ?? false,
                  ))
                .toList() ??
            [],
        notes: data['notes'] ?? '',
        startDate: DateTime.parse(data['start_date']),
        endDate: DateTime.parse(data['end_date']),
        color: _parseColor(data['color']),
      );

  Stream<List<Project>> streamProjects(String clinicId) {
    return _client
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .map((dataList) => dataList.map(_mapProject).toList());
  }

  Future<List<Project>> fetchProjects(String clinicId) async {
    final data =
        await _client.from('projects').select().eq('clinic_id', clinicId);
    return (data as List).map((row) => _mapProject(row)).toList();
  }

  Future<void> saveProject(Project p, String clinicId) async {
    try {
      List<String> assignIds = p.assignedTherapistIds;

      await _client.from('projects').upsert({
        'id': p.id,
        'clinic_id': clinicId,
        'title': p.title,
        'client_id': p.clientId,
        'first_name': p.firstName,
        'last_name': p.lastName,
        'client_code': p.clientCode,
        'date_of_birth': p.dateOfBirth?.toIso8601String(),
        'address': p.address,
        'phone': p.phone,
        'email': p.email,
        'client_type': p.clientType,
        'ndis_number': p.ndisNumber,
        'assigned_therapist_ids': assignIds,
        'contacts': p.contacts.map((c) => <String, dynamic>{
          'first_name': c.firstName,
          'last_name': c.lastName,
          'phone': c.phone,
          'email': c.email,
          'role': c.role,
          'is_primary': c.isPrimary,
        }).toList(),
        'notes': p.notes,
        'start_date': p.startDate.toIso8601String(),
        'end_date': p.endDate.toIso8601String(),
        'color': '#${p.color.value.toRadixString(16).padLeft(8, '0')}',
      });
    } catch (e) {
      debugPrint('SupabaseRepository.saveProject Error: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      await _client.from('projects').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteProject Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // TASKS
  // ---------------------------------------------------------------------------
  ProjectTask _mapTask(Map<String, dynamic> data) => ProjectTask(
        id: data['id'],
        projectId: data['project_id'],
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        status: _parseTaskStatus(data['status']),
        startDate: DateTime.parse(data['start_date']),
        endDate: DateTime.parse(data['end_date']),
        color: _parseColor(data['color']),
        assignedUserIds: (data['assigned_user_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  Stream<List<ProjectTask>> streamTasks(String clinicId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .map((dataList) => dataList.map(_mapTask).toList());
  }

  Future<List<ProjectTask>> fetchTasks(String clinicId) async {
    final data = await _client.from('tasks').select().eq('clinic_id', clinicId);
    return (data as List).map((row) => _mapTask(row)).toList();
  }

  Future<void> saveTask(ProjectTask t, String clinicId) async {
    try {
      List<String> assignIds = t.assignedUserIds;
      await _client.from('tasks').upsert({
        'id': t.id,
        'clinic_id': clinicId,
        'project_id': t.projectId,
        'title': t.title,
        'description': t.description,
        'status': t.status.name,
        'start_date': t.startDate.toIso8601String(),
        'end_date': t.endDate.toIso8601String(),
        'assigned_user_ids': assignIds,
        'color': '#${t.color.value.toRadixString(16).padLeft(8, '0')}',
      });
    } catch (e) {
      debugPrint('SupabaseRepository.saveTask Error: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _client.from('tasks').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteTask Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // SUBTASKS
  // ---------------------------------------------------------------------------
  Subtask _mapSubtask(Map<String, dynamic> data) => Subtask(
        id: data['id'],
        taskId: data['task_id'],
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        status: _parseTaskStatus(data['status']),
        startDate: DateTime.parse(data['start_date']),
        endDate: DateTime.parse(data['end_date']),
        color: _parseColorNullable(data['color']),
        assignedUserIds: (data['assigned_user_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  Stream<List<Subtask>> streamSubtasks(String clinicId) {
    return _client
        .from('subtasks')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .map((dataList) => dataList.map(_mapSubtask).toList());
  }

  Future<List<Subtask>> fetchSubtasks(String clinicId) async {
    final data =
        await _client.from('subtasks').select().eq('clinic_id', clinicId);
    return (data as List).map((row) => _mapSubtask(row)).toList();
  }

  Future<void> saveSubtask(Subtask s, String clinicId) async {
    try {
      List<String> assignIds = s.assignedUserIds;
      await _client.from('subtasks').upsert({
        'id': s.id,
        'clinic_id': clinicId,
        'task_id': s.taskId,
        'title': s.title,
        'description': s.description,
        'status': s.status.name,
        'start_date': s.startDate.toIso8601String(),
        'end_date': s.endDate.toIso8601String(),
        'assigned_user_ids': assignIds,
        'color': s.color != null
            ? '#${s.color!.value.toRadixString(16).padLeft(8, '0')}'
            : null,
      });
    } catch (e) {
      debugPrint('SupabaseRepository.saveSubtask Error: $e');
      rethrow;
    }
  }

  Future<void> deleteSubtask(String id) async {
    try {
      await _client.from('subtasks').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteSubtask Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------
  Session _mapSession(Map<String, dynamic> data) => Session(
        id: data['id'],
        clientId: data['client_id'] ?? '',
        therapistIds: (data['therapist_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        date: DateTime.parse(
          data['date'] ?? DateTime.now().toIso8601String(),
        ),
        durationMinutes: data['duration_minutes'] ?? 60,
        type: _parseSessionType(data['type']),
        status: _parseSessionStatus(data['status']),
        generalMood: data['general_mood'] ?? '',
        generalDiscussion: data['general_discussion'] ?? '',
        therapistNotes: data['therapist_notes'] ?? '',
      );

  Stream<List<Session>> streamSessions(String clinicId) {
    return _client
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .map((dataList) => dataList.map(_mapSession).toList());
  }

  Future<List<Session>> fetchSessions(String clinicId) async {
    final data =
        await _client.from('sessions').select().eq('clinic_id', clinicId);
    return (data as List).map((row) => _mapSession(row)).toList();
  }

  Future<void> saveSession(Session s, String clinicId) async {
    try {
      List<String> assignIds = s.therapistIds;
      await _client.from('sessions').upsert({
        'id': s.id,
        'clinic_id': clinicId,
        'client_id': s.clientId,
        'therapist_ids': assignIds,
        'date': s.date.toIso8601String(),
        'duration_minutes': s.durationMinutes,
        'type': s.type.name,
        'status': s.status.name,
        'general_mood': s.generalMood,
        'general_discussion': s.generalDiscussion,
        'therapist_notes': s.therapistNotes,
      });
    } catch (e) {
      debugPrint('SupabaseRepository.saveSession Error: $e');
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _client.from('sessions').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteSession Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // USERS & INVITES
  // ---------------------------------------------------------------------------
  Stream<List<UserInvite>> streamInvites(String clinicId) {
    return _client
        .from('invites')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .map((dataList) => dataList.map(_mapInvite).toList());
  }

  UserInvite _mapInvite(Map<String, dynamic> data) => UserInvite(
        id: data['id'],
        clinicId: data['clinic_id'],
        email: data['email'],
        role: data['role'],
        createdBy: data['created_by'] ?? '',
        createdAt: DateTime.parse(data['created_at']),
      );

  Future<void> deleteInvite(String id) async {
    try {
      await _client.from('invites').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteInvite Error: $e');
      rethrow;
    }
  }

  Future<void> inviteUser(String email, String role, String clinicId) async {
    try {
      // 1. Log the invite in our database for the trigger to pick up later
      await _client.from('invites').upsert({
        'clinic_id': clinicId,
        'email': email,
        'role': role,
        'created_by': _client.auth.currentUser?.id,
      });

      // 2. Trigger the Edge Function to send the actual Auth email
      // Note: This requires the 'invite-user' function to be deployed to Supabase
      try {
        await _client.functions.invoke(
          'invite-user',
          body: {
            'email': email,
            'role': role,
            'clinicId': clinicId,
          },
        );
      } catch (fError) {
        // We log but don't fail, as the database entry is the source of truth
        debugPrint('Invite Email Function Warning: $fError');
      }
    } catch (e) {
      debugPrint('SupabaseRepository.inviteUser Error: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _client.from('users').delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseRepository.deleteUser Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  TaskStatus _parseTaskStatus(String? name) {
    if (name == TaskStatus.done.name) return TaskStatus.done;
    if (name == TaskStatus.inProgress.name) return TaskStatus.inProgress;
    return TaskStatus.todo;
  }

  SessionType _parseSessionType(String? name) {
    if (name == SessionType.group.name) return SessionType.group;
    if (name == SessionType.telehealth.name) return SessionType.telehealth;
    if (name == SessionType.homeVisit.name) return SessionType.homeVisit;
    return SessionType.individual;
  }

  SessionStatus _parseSessionStatus(String? name) {
    if (name == SessionStatus.completed.name) return SessionStatus.completed;
    if (name == SessionStatus.cancelled.name) return SessionStatus.cancelled;
    if (name == SessionStatus.noShow.name) return SessionStatus.noShow;
    return SessionStatus.scheduled;
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF38BDF8);
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF38BDF8);
    }
  }
  Color? _parseColorNullable(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
