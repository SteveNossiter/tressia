import 'package:flutter/material.dart';

// =============================================
// USER ROLES
// =============================================
// admin / administrator: Full access. Also listed as a therapist.
// therapist: Can see own clients, session data, request assignments.
// receptionist: Admin functions + new client creation + send requests.
// =============================================
enum UserRole { admin, administrator, therapist, receptionist }

// =============================================
// APP USER — Full profile with AHPRA-compliant fields
// =============================================
class AppUser {
  final String id;
  final String clinicId;
  final String name;
  final String firstName;
  final String lastName;
  final UserRole role;
  final Color userColor;

  // Contact
  final String email;
  final String phone;
  final String address;
  final String? base64Photo; // Profile photo

  // Professional
  final DateTime? startDate; // Employment start
  final String ahpraNumber; // AHPRA registration # (therapists)
  final String qualifications;
  final String notes;

  // Auth
  final bool setupComplete;
  final String passwordHash; // Stored hashed password
  final bool twoFactorEnabled;

  AppUser({
    required this.id,
    required this.clinicId,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.role,
    required this.userColor,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.base64Photo,
    this.startDate,
    this.ahpraNumber = '',
    this.qualifications = '',
    this.notes = '',
    this.passwordHash = '',
    this.twoFactorEnabled = false,
    this.setupComplete = false,
  });

  bool get isAdmin => role == UserRole.admin || role == UserRole.administrator;
  bool get isSuperAdmin => role == UserRole.administrator;
  bool get isTherapist =>
      role == UserRole.therapist || isAdmin; // Admin is also a therapist
  bool get isReceptionist => role == UserRole.receptionist;

  String get displayName =>
      name.isNotEmpty ? name : '$firstName $lastName'.trim();
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  AppUser copyWith({
    String? name,
    String? firstName,
    String? lastName,
    UserRole? role,
    Color? userColor,
    String? email,
    String? phone,
    String? address,
    String? base64Photo,
    DateTime? startDate,
    String? ahpraNumber,
    String? qualifications,
    String? notes,
    bool? setupComplete,
  }) =>
      AppUser(
        id: id,
        clinicId: clinicId,
        name: name ?? this.name,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role ?? this.role,
        userColor: userColor ?? this.userColor,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        base64Photo: base64Photo ?? this.base64Photo,
        startDate: startDate ?? this.startDate,
        ahpraNumber: ahpraNumber ?? this.ahpraNumber,
        qualifications: qualifications ?? this.qualifications,
        notes: notes ?? this.notes,
        passwordHash: passwordHash ?? this.passwordHash,
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        setupComplete: setupComplete ?? this.setupComplete,
      );
}

// =============================================
// ASSIGNMENT REQUEST — therapist-to-therapist
// =============================================
enum AssignmentRequestStatus { pending, approved, rejected }

class AssignmentRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String entityType; // 'phase', 'task', 'subtask'
  final String entityId;
  final String entityTitle;
  final String message;
  final AssignmentRequestStatus status;
  final DateTime createdAt;

  AssignmentRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    this.message = '',
    this.status = AssignmentRequestStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// =============================================
// CLINIC SETTINGS
// =============================================
class ClinicSettings {
  final String id;
  final String clinicName;
  final String description;
  final String address;
  final String phone;
  final String email;
  final String? base64Logo;
  final bool setupComplete;

  // Reporting prefs
  final int dailyReportHour; // 0-23
  final int weeklyReportDay; // 1=Mon, 5=Fri
  final int weeklyReportHour;

  ClinicSettings({
    required this.id,
    this.clinicName = 'Tressia Art Therapy',
    this.description =
        'A warm, nurturing art therapy clinic supporting creative healing and self-expression.',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.base64Logo,
    this.setupComplete = false,
    this.dailyReportHour = 19, // 7pm
    this.weeklyReportDay = 5, // Friday
    this.weeklyReportHour = 19, // 7pm
  });

  ClinicSettings copyWith({
    String? clinicName,
    String? description,
    String? address,
    String? phone,
    String? email,
    String? base64Logo,
    bool? setupComplete,
    int? dailyReportHour,
    int? weeklyReportDay,
    int? weeklyReportHour,
  }) =>
      ClinicSettings(
        id: id,
        clinicName: clinicName ?? this.clinicName,
        description: description ?? this.description,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        base64Logo: base64Logo ?? this.base64Logo,
        setupComplete: setupComplete ?? this.setupComplete,
        dailyReportHour: dailyReportHour ?? this.dailyReportHour,
        weeklyReportDay: weeklyReportDay ?? this.weeklyReportDay,
        weeklyReportHour: weeklyReportHour ?? this.weeklyReportHour,
      );
}
