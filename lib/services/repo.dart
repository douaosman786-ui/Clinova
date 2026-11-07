import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clinic_time.dart';
import '../models/models.dart';

/// Accès aux collections Firestore (lecture).
/// Les requêtes sont volontairement simples (un seul champ filtré ou une plage
/// sur startAt) afin de fonctionner sans index composite ; le tri est fait côté app.
class Repo {
  Repo._();

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  static CollectionReference<Map<String, dynamic>> get patients => db.collection('patients');
  static CollectionReference<Map<String, dynamic>> get doctors => db.collection('doctors');
  static CollectionReference<Map<String, dynamic>> get schedules => db.collection('doctorSchedules');
  static CollectionReference<Map<String, dynamic>> get appointments => db.collection('appointments');
  static CollectionReference<Map<String, dynamic>> get reservations => db.collection('slotReservations');
  static CollectionReference<Map<String, dynamic>> get notifications => db.collection('notifications');
  static DocumentReference<Map<String, dynamic>> get bootstrapDoc =>
      db.collection('config').doc('bootstrap');

  // ---------- Médecins ----------
  static Stream<List<Doctor>> doctorsStream({bool activeOnly = false}) {
    return doctors.snapshots().map((s) {
      final list = s.docs.map(Doctor.fromDoc).where((d) => !activeOnly || d.isActive).toList();
      list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return list;
    });
  }

  static Future<Doctor?> getDoctor(String doctorId) async {
    final doc = await doctors.doc(doctorId).get();
    return doc.exists ? Doctor.fromDoc(doc) : null;
  }

  // ---------- Horaires ----------
  static Stream<List<DoctorSchedule>> schedulesStream(String doctorId) {
    return schedules.where('doctorId', isEqualTo: doctorId).snapshots().map((s) {
      final list = s.docs.map(DoctorSchedule.fromDoc).toList();
      list.sort((a, b) {
        final da = ClinicTime.workWeekOrder.indexOf(a.dayOfWeek);
        final dbi = ClinicTime.workWeekOrder.indexOf(b.dayOfWeek);
        if (da != dbi) return da.compareTo(dbi);
        return a.startMinutes.compareTo(b.startMinutes);
      });
      return list;
    });
  }

  static Future<List<DoctorSchedule>> getSchedules(String doctorId) async {
    final s = await schedules.where('doctorId', isEqualTo: doctorId).get();
    return s.docs.map(DoctorSchedule.fromDoc).toList();
  }

  // ---------- Patients ----------
  static Stream<List<Patient>> patientsStream() {
    return patients.snapshots().map((s) {
      final list = s.docs.map(Patient.fromDoc).toList();
      list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return list;
    });
  }

  static Future<Patient?> getPatient(String patientId) async {
    final doc = await patients.doc(patientId).get();
    return doc.exists ? Patient.fromDoc(doc) : null;
  }

  static Stream<Patient?> patientStream(String patientId) {
    return patients.doc(patientId).snapshots().map((d) => d.exists ? Patient.fromDoc(d) : null);
  }

  // ---------- Utilisateurs ----------
  static Stream<List<UserProfile>> usersStream() {
    return users.snapshots().map((s) {
      final list = s.docs.map(UserProfile.fromDoc).toList();
      list.sort((a, b) {
        final r = a.role.index.compareTo(b.role.index);
        return r != 0 ? r : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
      return list;
    });
  }

  // ---------- Rendez-vous ----------
  static List<Appointment> _sorted(QuerySnapshot<Map<String, dynamic>> s, {bool desc = false}) {
    final list = s.docs.map(Appointment.fromDoc).toList();
    list.sort((a, b) => desc ? b.startAt.compareTo(a.startAt) : a.startAt.compareTo(b.startAt));
    return list;
  }

  /// Rendez-vous d'un patient connecté (règle : patientUid == uid).
  static Stream<List<Appointment>> appointmentsForPatientUid(String uid) =>
      appointments.where('patientUid', isEqualTo: uid).snapshots().map((s) => _sorted(s));

  /// Rendez-vous d'un dossier patient (personnel de la clinique).
  static Stream<List<Appointment>> appointmentsForPatientId(String patientId) =>
      appointments.where('patientId', isEqualTo: patientId).snapshots().map((s) => _sorted(s, desc: true));

  /// Rendez-vous d'un médecin (règle : doctorId == doctorId du compte).
  static Stream<List<Appointment>> appointmentsForDoctor(String doctorId) =>
      appointments.where('doctorId', isEqualTo: doctorId).snapshots().map((s) => _sorted(s));

  /// Tous les rendez-vous d'une journée de la clinique (personnel).
  static Stream<List<Appointment>> appointmentsForDay(DateTime wallDay) {
    final start = ClinicTime.dayStartInstant(wallDay);
    final end = ClinicTime.dayEndInstant(wallDay);
    return appointments
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => _sorted(s));
  }

  static Future<List<Appointment>> appointmentsBetween(DateTime start, DateTime end) async {
    final s = await appointments
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return _sorted(s);
  }

  static Future<List<Appointment>> appointmentsByField(String field, String value) async {
    final s = await appointments.where(field, isEqualTo: value).get();
    return _sorted(s, desc: true);
  }

  static Future<List<Appointment>> recentAppointments({int limit = 200}) async {
    final s = await appointments.orderBy('startAt', descending: true).limit(limit).get();
    return _sorted(s, desc: true);
  }

  // ---------- Notifications ----------
  static Stream<List<AppNotification>> notificationsFor(String uid) {
    return notifications.where('recipientUid', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map(AppNotification.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? b.startAt).compareTo(a.createdAt ?? a.startAt));
      return list;
    });
  }

  static Future<void> markNotificationRead(String id) =>
      notifications.doc(id).update({'read': true});

  static Future<void> markAllNotificationsRead(List<AppNotification> items) async {
    final unread = items.where((n) => !n.read).toList();
    for (var i = 0; i < unread.length; i += 400) {
      final batch = db.batch();
      for (final n in unread.skip(i).take(400)) {
        batch.update(notifications.doc(n.id), {'read': true});
      }
      await batch.commit();
    }
  }

  static Future<void> deleteNotification(String id) => notifications.doc(id).delete();

  // ---------- Réservations ----------
  /// Identifiants des créneaux réservés pour un médecin un jour donné.
  static Future<Set<String>> reservedIdsForDay(String doctorId, DateTime wallDay) async {
    final start = ClinicTime.dayStartInstant(wallDay);
    final end = ClinicTime.dayEndInstant(wallDay);
    final s = await reservations
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return s.docs.where((d) => d.data()['doctorId'] == doctorId).map((d) => d.id).toSet();
  }
}
