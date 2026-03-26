// =============================================
// Firebase Repository Layer
//
// SETUP INSTRUCTIONS:
// 1. Create a Firebase project at console.firebase.google.com
// 2. Install FlutterFire CLI: dart pub global activate flutterfire_cli
// 3. Run: flutterfire configure
// 4. Enable Authentication (Email/Password) in Firebase Console
// 5. Enable Firestore Database
// 6. Enable Storage
// 7. Replace the mock providers in app_state.dart with FirestoreRepository calls
//
// DATA STRUCTURE (Firestore):
//   /clinics/{clinicId}/
//     /clients/{clientId}   → Project model
//     /sessions/{sessionId} → Session model
//     /tasks/{taskId}       → ProjectTask model
//     /subtasks/{subtaskId} → Subtask model
//     /providers/{provId}   → NdisProvider model
//     /users/{userId}       → AppUser model
//     /settings             → ClinicSettings model
// =============================================
// ignore_for_file: unused_import

import '../models/project_module.dart';
import '../models/clinic_settings.dart';

/// Abstract interface — currently implemented in-memory via Riverpod providers.
/// Swap any method for a Firestore implementation when Firebase is configured.
abstract class TressiaRepository {
  // Clients
  Future<List<Project>> getClients();
  Future<void> saveClient(Project client);
  Future<void> deleteClient(String clientId);

  // Sessions
  Future<List<Session>> getSessions({String? clientId});
  Future<void> saveSession(Session session);
  Future<void> deleteSession(String sessionId);

  // Tasks
  Future<List<ProjectTask>> getTasks({String? projectId});
  Future<void> saveTask(ProjectTask task);
  Future<void> deleteTask(String taskId);

  // Subtasks
  Future<List<Subtask>> getSubtasks({String? taskId});
  Future<void> saveSubtask(Subtask subtask);
  Future<void> deleteSubtask(String subtaskId);

  // Providers
  Future<List<NdisProvider>> getProviders();
  Future<void> saveProvider(NdisProvider provider);
  Future<void> deleteProvider(String providerId);

  // Users
  Future<List<AppUser>> getUsers();
  Future<void> saveUser(AppUser user);

  // Settings
  Future<ClinicSettings> getSettings();
  Future<void> saveSettings(ClinicSettings settings);
}

// =============================================
// Firestore Implementation (ready to activate)
// =============================================
// Uncomment this class and import firebase packages once
// `flutterfire configure` has been run:
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class FirestoreRepository implements TressiaRepository {
//   final _db = FirebaseFirestore.instance;
//   final String clinicId; // Set from auth token / shared prefs after login
//
//   FirestoreRepository({required this.clinicId});
//
//   CollectionReference get _clients => _db.collection('clinics/$clinicId/clients');
//   CollectionReference get _sessions => _db.collection('clinics/$clinicId/sessions');
//   CollectionReference get _tasks => _db.collection('clinics/$clinicId/tasks');
//   CollectionReference get _subtasks => _db.collection('clinics/$clinicId/subtasks');
//   CollectionReference get _providers => _db.collection('clinics/$clinicId/providers');
//   CollectionReference get _users => _db.collection('clinics/$clinicId/users');
//   DocumentReference get _settings => _db.doc('clinics/$clinicId/settings/main');
//
//   @override
//   Future<List<Project>> getClients() async {
//     final snap = await _clients.get();
//     return snap.docs.map((d) => _projectFromMap(d.id, d.data() as Map<String, dynamic>)).toList();
//   }
//
//   @override
//   Future<void> saveClient(Project client) async {
//     await _clients.doc(client.id).set(_projectToMap(client));
//   }
//
//   // ... implement all methods similarly
// }

// =============================================
// SUBSCRIPTION TIER DEFINITIONS
// =============================================
enum SubscriptionTier { starter, clinic, enterprise }

class SubscriptionLimits {
  final int maxTherapists;
  final int maxClients;
  final bool ndisReports;
  final bool aiSummaries;
  final bool whiteLabel;
  final bool apiAccess;
  final bool multiSite;

  const SubscriptionLimits({
    required this.maxTherapists,
    required this.maxClients,
    required this.ndisReports,
    required this.aiSummaries,
    required this.whiteLabel,
    required this.apiAccess,
    required this.multiSite,
  });

  static const Map<SubscriptionTier, SubscriptionLimits> tiers = {
    SubscriptionTier.starter: SubscriptionLimits(
      maxTherapists: 1,
      maxClients: 30,
      ndisReports: false,
      aiSummaries: false,
      whiteLabel: false,
      apiAccess: false,
      multiSite: false,
    ),
    SubscriptionTier.clinic: SubscriptionLimits(
      maxTherapists: 5,
      maxClients: 200,
      ndisReports: true,
      aiSummaries: true,
      whiteLabel: false,
      apiAccess: false,
      multiSite: false,
    ),
    SubscriptionTier.enterprise: SubscriptionLimits(
      maxTherapists: 999,
      maxClients: 999999,
      ndisReports: true,
      aiSummaries: true,
      whiteLabel: true,
      apiAccess: true,
      multiSite: true,
    ),
  };
}
