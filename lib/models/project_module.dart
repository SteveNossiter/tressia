import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// =============================================
// ENUMS
// =============================================
enum TaskStatus { todo, inProgress, done }

enum SessionType { individual, group, telehealth, homeVisit }

enum SessionStatus { scheduled, completed, cancelled, noShow }

enum ProviderType { ndis, medicare, referrer, specialist, other }

// =============================================
// CLIENT CODE GENERATOR
// Generates: 1st initial + last initial + 3-digit counter
// e.g. "John Doe" => "JD001"
// =============================================
String generateClientCode(String firstName, String lastName, int index) {
  final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'X';
  final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : 'X';
  final num = (index + 1).toString().padLeft(3, '0');
  return '$f$l$num';
}

// =============================================
// CONTACT  — reusable mini-model
// =============================================
class Contact {
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String role; // e.g. "Plan Manager", "CMH Coordinator"
  final bool isPrimary;

  const Contact({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.role = '',
    this.isPrimary = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  Contact copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? role,
    bool? isPrimary,
  }) => Contact(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    role: role ?? this.role,
    isPrimary: isPrimary ?? this.isPrimary,
  );
}

// =============================================
// PROJECT / CLIENT (Phase)
// =============================================
class Project {
  final String id;
  final String title; // e.g. "John Doe - Therapy"
  final String clientId;

  // Personal Details
  final String firstName;
  final String lastName;
  final String clientCode; // Auto-generated: JD001
  final DateTime? dateOfBirth;
  final String address;
  final String phone;
  final String email;

  // Funding / Type
  final String clientType; // NDIS, Private, Medicare, WorkCover
  final String ndisNumber; // Only for NDIS
  final List<String> assignedTherapistIds;

  // Contacts
  final List<Contact> contacts;

  // Meta
  final String notes;
  final DateTime startDate;
  final DateTime endDate;
  final double progress;
  final Color color;

  Project({
    String? id,
    required this.title,
    required this.clientId,
    this.firstName = '',
    this.lastName = '',
    this.clientCode = '',
    this.dateOfBirth,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.clientType = 'Private',
    this.ndisNumber = '',
    this.assignedTherapistIds = const [],
    this.contacts = const [],
    this.notes = '',
    required this.startDate,
    required this.endDate,
    this.progress = 0.0,
    this.color = const Color(0xFF38BDF8),
  }) : id = id ?? const Uuid().v4();

  // Helper getters for compatibility
  Contact? get planManager =>
      contacts.where((c) => c.role == 'Plan Manager').firstOrNull;
  Contact? get planCoordinator =>
      contacts.where((c) => c.role == 'Plan Coordinator').firstOrNull;
  Contact? get cmhContact =>
      contacts.where((c) => c.role == 'CMH Contact').firstOrNull;
  Contact? get emergencyContact =>
      contacts.where((c) => c.role == 'Emergency Contact').firstOrNull;
  Contact? get primaryContact => contacts.where((c) => c.isPrimary).firstOrNull;

  // Keep backward compat
  String get clientName => firstName.isNotEmpty || lastName.isNotEmpty
      ? '$firstName $lastName'.trim()
      : title;

  String get clientCodeDisplay => clientCode.isNotEmpty
      ? clientCode
      : title.substring(0, title.length.clamp(0, 6)).toUpperCase();

  Project copyWith({
    String? title,
    String? clientId,
    String? firstName,
    String? lastName,
    String? clientCode,
    DateTime? dateOfBirth,
    String? address,
    String? phone,
    String? email,
    String? clientType,
    String? ndisNumber,
    List<String>? assignedTherapistIds,
    List<Contact>? contacts,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    double? progress,
    Color? color,
  }) => Project(
    id: id,
    title: title ?? this.title,
    clientId: clientId ?? this.clientId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    clientCode: clientCode ?? this.clientCode,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    clientType: clientType ?? this.clientType,
    ndisNumber: ndisNumber ?? this.ndisNumber,
    assignedTherapistIds: assignedTherapistIds ?? this.assignedTherapistIds,
    contacts: contacts ?? this.contacts,
    notes: notes ?? this.notes,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    progress: progress ?? this.progress,
    color: color ?? this.color,
  );
}

// =============================================
// SESSION
// =============================================
class Session {
  final String id;
  final String clientId; // links to Project.id
  final List<String> therapistIds;
  final DateTime date;
  final int durationMinutes;
  final SessionType type;
  final SessionStatus status;

  // Content
  final String generalMood; // e.g. "anxious", "positive"
  final List<String> topics;
  final String generalDiscussion;
  final List<String> actionItems;
  final String improvements;
  final String regressions;

  // Scheduling
  final TimeOfDay? startTime;

  // Recording & AI
  final String? recordingPath;
  final bool isTranscribed;
  final String transcriptText;
  final String aiSummary;
  final String aiTopicsSummary;
  final String clinicalReport; // Formal report generated after session

  // Notes
  final String therapistNotes;

  Session({
    String? id,
    required this.clientId,
    this.therapistIds = const [],
    required this.date,
    this.startTime,
    this.durationMinutes = 60,
    this.type = SessionType.individual,
    this.status = SessionStatus.scheduled,
    this.generalMood = '',
    this.topics = const [],
    this.generalDiscussion = '',
    this.actionItems = const [],
    this.improvements = '',
    this.regressions = '',
    this.recordingPath,
    this.isTranscribed = false,
    this.transcriptText = '',
    this.aiSummary = '',
    this.aiTopicsSummary = '',
    this.clinicalReport = '',
    this.therapistNotes = '',
  }) : id = id ?? const Uuid().v4();

  Session copyWith({
    String? clientId,
    List<String>? therapistIds,
    DateTime? date,
    TimeOfDay? startTime,
    int? durationMinutes,
    SessionType? type,
    SessionStatus? status,
    String? generalMood,
    List<String>? topics,
    String? generalDiscussion,
    List<String>? actionItems,
    String? improvements,
    String? regressions,
    String? recordingPath,
    bool? isTranscribed,
    String? transcriptText,
    String? aiSummary,
    String? aiTopicsSummary,
    String? clinicalReport,
    String? therapistNotes,
  }) => Session(
    id: id,
    clientId: clientId ?? this.clientId,
    therapistIds: therapistIds ?? this.therapistIds,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    type: type ?? this.type,
    status: status ?? this.status,
    generalMood: generalMood ?? this.generalMood,
    topics: topics ?? this.topics,
    generalDiscussion: generalDiscussion ?? this.generalDiscussion,
    actionItems: actionItems ?? this.actionItems,
    improvements: improvements ?? this.improvements,
    regressions: regressions ?? this.regressions,
    recordingPath: recordingPath ?? this.recordingPath,
    isTranscribed: isTranscribed ?? this.isTranscribed,
    transcriptText: transcriptText ?? this.transcriptText,
    aiSummary: aiSummary ?? this.aiSummary,
    aiTopicsSummary: aiTopicsSummary ?? this.aiTopicsSummary,
    clinicalReport: clinicalReport ?? this.clinicalReport,
    therapistNotes: therapistNotes ?? this.therapistNotes,
  );
}

// =============================================
// NDIS / EXTERNAL PROVIDER
// =============================================
class NdisProvider {
  final String id;
  final String businessName;
  final ProviderType type;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final List<String> associatedClientIds;
  final DateTime createdAt;

  NdisProvider({
    String? id,
    required this.businessName,
    this.type = ProviderType.ndis,
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.associatedClientIds = const [],
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  NdisProvider copyWith({
    String? businessName,
    ProviderType? type,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? notes,
    List<String>? associatedClientIds,
  }) => NdisProvider(
    id: id,
    businessName: businessName ?? this.businessName,
    type: type ?? this.type,
    contactName: contactName ?? this.contactName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    associatedClientIds: associatedClientIds ?? this.associatedClientIds,
    createdAt: createdAt,
  );
}

// =============================================
// PROJECT TASK
// =============================================
class ProjectTask {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final Color color;
  final List<String> assignedUserIds;

  ProjectTask({
    String? id,
    required this.projectId,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    required this.startDate,
    required this.endDate,
    this.color = const Color(0xFF38BDF8),
    this.assignedUserIds = const [],
  }) : id = id ?? const Uuid().v4();

  ProjectTask copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    Color? color,
    List<String>? assignedUserIds,
  }) => ProjectTask(
    id: id,
    projectId: projectId,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    color: color ?? this.color,
    assignedUserIds: assignedUserIds ?? this.assignedUserIds,
  );
}

// =============================================
// SUBTASK
// =============================================
class Subtask {
  final String id;
  final String taskId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> assignedUserIds;
  final Color? color;

  Subtask({
    String? id,
    required this.taskId,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    required this.startDate,
    required this.endDate,
    this.assignedUserIds = const [],
    this.color,
  }) : id = id ?? const Uuid().v4();

  Subtask copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? assignedUserIds,
    Color? color,
  }) => Subtask(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    color: color ?? this.color,
  );
}
