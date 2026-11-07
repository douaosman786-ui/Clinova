import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clinic_time.dart';

/// «enumeration» UserRole {Patient, Doctor, Receptionist, Administrator}
enum UserRole {
  patient('patient'),
  doctor('doctor'),
  receptionist('receptionist'),
  administrator('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(String? v) => UserRole.values.firstWhere(
        (r) => r.value == v,
        orElse: () => UserRole.patient,
      );

  String get trKey => 'role_$value';
  bool get isStaff => this == UserRole.receptionist || this == UserRole.administrator;
}

/// «enumeration» AppointmentStatus {Scheduled, Completed, Cancelled}
enum AppointmentStatus {
  scheduled('Scheduled'),
  completed('Completed'),
  cancelled('Cancelled');

  const AppointmentStatus(this.value);
  final String value;

  static AppointmentStatus fromValue(String? v) => AppointmentStatus.values.firstWhere(
        (s) => s.value == v,
        orElse: () => AppointmentStatus.scheduled,
      );

  String get trKey => 'status_${value.toLowerCase()}';
}

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  return null;
}

String _str(dynamic v) => v is String ? v : '';
String? _strOrNull(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

/// users/{uid}
class UserProfile {
  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.patientId,
    this.doctorId,
    this.language,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final String? patientId;
  final String? doctorId;
  final String? language;
  final DateTime? createdAt;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      fullName: _str(d['fullName']),
      email: _str(d['email']),
      phone: _str(d['phone']),
      role: UserRole.fromValue(d['role'] as String?),
      isActive: d['isActive'] == true,
      patientId: _strOrNull(d['patientId']),
      doctorId: _strOrNull(d['doctorId']),
      language: _strOrNull(d['language']),
      createdAt: _ts(d['createdAt']),
    );
  }
}

/// patients/{patientId}
class Patient {
  Patient({
    required this.patientId,
    required this.fullName,
    required this.phone,
    this.userUid,
    this.email,
    this.dateOfBirth,
    this.createdByUid,
    this.createdAt,
  });

  final String patientId;
  final String fullName;
  final String phone;
  final String? userUid;
  final String? email;
  final String? dateOfBirth; // AAAA-MM-JJ
  final String? createdByUid;
  final DateTime? createdAt;

  bool get hasAccount => userUid != null;

  factory Patient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Patient(
      patientId: doc.id,
      fullName: _str(d['fullName']),
      phone: _str(d['phone']),
      userUid: _strOrNull(d['userUid']),
      email: _strOrNull(d['email']),
      dateOfBirth: _strOrNull(d['dateOfBirth']),
      createdByUid: _strOrNull(d['createdByUid']),
      createdAt: _ts(d['createdAt']),
    );
  }
}

/// doctors/{doctorId}
class Doctor {
  Doctor({
    required this.doctorId,
    required this.fullName,
    required this.specialization,
    required this.isActive,
    this.phone,
    this.email,
    this.userUid,
  });

  final String doctorId;
  final String fullName;
  final String specialization; // clé (general, pediatrics…)
  final bool isActive;
  final String? phone;
  final String? email;
  final String? userUid;

  factory Doctor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Doctor(
      doctorId: doc.id,
      fullName: _str(d['fullName']),
      specialization: _str(d['specialization']).isEmpty ? 'general' : _str(d['specialization']),
      isActive: d['isActive'] == true,
      phone: _strOrNull(d['phone']),
      email: _strOrNull(d['email']),
      userUid: _strOrNull(d['userUid']),
    );
  }
}

/// doctorSchedules/{scheduleId}
class DoctorSchedule {
  DoctorSchedule({
    required this.scheduleId,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.isAvailable,
  });

  final String scheduleId;
  final String doctorId;
  final int dayOfWeek; // 1 = lundi … 7 = dimanche (DateTime.weekday)
  final int startMinutes;
  final int endMinutes;
  final bool isAvailable;

  String get startTime => ClinicTime.minutesToHHmm(startMinutes);
  String get endTime => ClinicTime.minutesToHHmm(endMinutes);

  factory DoctorSchedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return DoctorSchedule(
      scheduleId: doc.id,
      doctorId: _str(d['doctorId']),
      dayOfWeek: _int(d['dayOfWeek']),
      startMinutes: _int(d['startMinutes']),
      endMinutes: _int(d['endMinutes']),
      isAvailable: d['isAvailable'] == true,
    );
  }

  static Map<String, dynamic> toMap({
    required String doctorId,
    required int dayOfWeek,
    required int startMinutes,
    required int endMinutes,
    required bool isAvailable,
  }) =>
      {
        'doctorId': doctorId,
        'dayOfWeek': dayOfWeek,
        'startTime': ClinicTime.minutesToHHmm(startMinutes),
        'endTime': ClinicTime.minutesToHHmm(endMinutes),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'isAvailable': isAvailable,
      };
}

/// appointments/{appointmentId}
class Appointment {
  Appointment({
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.reservationId,
    required this.scheduleId,
    required this.patientName,
    required this.doctorName,
    required this.doctorSpecialization,
    this.patientUid,
    this.doctorUid,
    this.patientPhone,
    this.patientDateOfBirth,
    this.bookedByUid,
    this.createdAt,
  });

  final String appointmentId;
  final String patientId;
  final String? patientUid;
  final String doctorId;
  final String? doctorUid;
  final DateTime startAt; // instant UTC
  final DateTime endAt;
  final AppointmentStatus status;
  final String reservationId;
  final String scheduleId;
  final String patientName;
  final String? patientPhone;
  final String? patientDateOfBirth;
  final String doctorName;
  final String doctorSpecialization;
  final String? bookedByUid;
  final DateTime? createdAt;

  bool get isScheduled => status == AppointmentStatus.scheduled;
  bool get isUpcoming => isScheduled && startAt.isAfter(DateTime.now().toUtc());

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final start = _ts(d['startAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Appointment(
      appointmentId: doc.id,
      patientId: _str(d['patientId']),
      patientUid: _strOrNull(d['patientUid']),
      doctorId: _str(d['doctorId']),
      doctorUid: _strOrNull(d['doctorUid']),
      startAt: start,
      endAt: _ts(d['endAt']) ?? start.add(ClinicTime.slotDuration),
      status: AppointmentStatus.fromValue(d['status'] as String?),
      reservationId: _str(d['reservationId']),
      scheduleId: _str(d['scheduleId']),
      patientName: _str(d['patientName']),
      patientPhone: _strOrNull(d['patientPhone']),
      patientDateOfBirth: _strOrNull(d['patientDateOfBirth']),
      doctorName: _str(d['doctorName']),
      doctorSpecialization: _str(d['doctorSpecialization']),
      bookedByUid: _strOrNull(d['bookedByUid']),
      createdAt: _ts(d['createdAt']),
    );
  }
}

/// notifications/{id} — notification in-app (réservé, reporté, annulé, terminé).
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.appointmentId,
    required this.patientName,
    required this.doctorName,
    required this.startAt,
    required this.read,
    this.oldStartAt,
    this.createdAt,
  });

  final String id;
  final String type; // booked | rescheduled | cancelled | completed
  final String appointmentId;
  final String patientName;
  final String doctorName;
  final DateTime startAt;
  final DateTime? oldStartAt;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: _str(d['type']),
      appointmentId: _str(d['appointmentId']),
      patientName: _str(d['patientName']),
      doctorName: _str(d['doctorName']),
      startAt: _ts(d['startAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      oldStartAt: _ts(d['oldStartAt']),
      read: d['read'] == true,
      // createdAt peut être null un court instant (horodatage serveur en attente)
      createdAt: _ts(d['createdAt']) ?? DateTime.now().toUtc(),
    );
  }
}

/// Créneau disponible calculé (non stocké).
class Slot {
  Slot({required this.start, required this.scheduleId, required this.reserved});
  final DateTime start; // instant UTC
  final String scheduleId;
  final bool reserved;

  DateTime get end => start.add(ClinicTime.slotDuration);
}
