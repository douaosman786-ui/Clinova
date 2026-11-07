import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/clinic_time.dart';
import '../core/errors.dart';
import '../models/models.dart';
import 'repo.dart';

/// BookingService : réservation, annulation et report de rendez-vous.
///
/// Plan Firebase gratuit (Spark) : à la place d'une Cloud Function, chaque
/// opération est une transaction Firestore atomique. Les règles de sécurité
/// (firestore.rules) revalident côté serveur : rôle, propriétaire, créneau futur,
/// durée de 30 min, horaire du médecin, vendredi fermé, unicité du créneau.
class BookingService {
  BookingService._();

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw AppException('err_not_signed_in');
    return user.uid;
  }

  // ---------------------------------------------------------------------------
  // Calcul des créneaux disponibles (UC4)
  // ---------------------------------------------------------------------------
  static Future<List<Slot>> availableSlots({
    required String doctorId,
    required DateTime wallDay,
    String? ignoreReservationId,
  }) async {
    if (ClinicTime.isClosedDay(wallDay)) return [];
    final schedules = (await Repo.getSchedules(doctorId))
        .where((s) => s.isAvailable && s.dayOfWeek == wallDay.weekday)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    if (schedules.isEmpty) return [];

    final reserved = await Repo.reservedIdsForDay(doctorId, wallDay);
    final now = DateTime.now().toUtc();
    final seen = <int>{};
    final slots = <Slot>[];

    for (final s in schedules) {
      for (var m = s.startMinutes; m + ClinicTime.slotMinutes <= s.endMinutes; m += ClinicTime.slotMinutes) {
        if (m % ClinicTime.slotMinutes != 0) continue;
        final wall = DateTime.utc(wallDay.year, wallDay.month, wallDay.day).add(Duration(minutes: m));
        final start = ClinicTime.fromWall(wall);
        if (!start.isAfter(now)) continue; // seulement les créneaux futurs
        if (!seen.add(start.millisecondsSinceEpoch)) continue;
        final rid = ClinicTime.reservationId(doctorId, start);
        final isReserved = reserved.contains(rid) && rid != ignoreReservationId;
        slots.add(Slot(start: start, scheduleId: s.scheduleId, reserved: isReserved));
      }
    }
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  /// Validation locale (les règles Firestore refont la même vérification).
  static void _validateSlot(Doctor doctor, DoctorSchedule schedule, DateTime start) {
    final now = DateTime.now().toUtc();
    if (!start.isAfter(now)) throw AppException('err_past_slot');
    if (!doctor.isActive) throw AppException('err_doctor_inactive');
    final wall = ClinicTime.toWall(start);
    if (ClinicTime.isClosedDay(wall)) throw AppException('err_friday_closed');
    final minutes = wall.hour * 60 + wall.minute;
    if (minutes % ClinicTime.slotMinutes != 0) throw AppException('err_outside_schedule');
    if (schedule.doctorId != doctor.doctorId ||
        !schedule.isAvailable ||
        schedule.dayOfWeek != wall.weekday ||
        minutes < schedule.startMinutes ||
        minutes + ClinicTime.slotMinutes > schedule.endMinutes) {
      throw AppException('err_outside_schedule');
    }
  }

  static Future<DoctorSchedule> _getSchedule(String scheduleId) async {
    final doc = await Repo.schedules.doc(scheduleId).get();
    if (!doc.exists) throw AppException('err_outside_schedule');
    return DoctorSchedule.fromDoc(doc);
  }

  // ---------------------------------------------------------------------------
  // bookAtomically() — UC5
  // ---------------------------------------------------------------------------
  static Future<String> bookAtomically({
    required Patient patient,
    required Doctor doctor,
    required Slot slot,
  }) async {
    final uid = _uid;
    final start = slot.start.toUtc();
    final end = start.add(ClinicTime.slotDuration); // le serveur impose start + 30 min
    final schedule = await _getSchedule(slot.scheduleId);
    _validateSlot(doctor, schedule, start);

    final apptRef = Repo.appointments.doc();
    final rid = ClinicTime.reservationId(doctor.doctorId, start);
    final resvRef = Repo.reservations.doc(rid);

    try {
      await Repo.db.runTransaction((tx) async {
        final existing = await tx.get(resvRef);
        if (existing.exists) throw AppException('err_slot_taken');

        tx.set(resvRef, {
          'doctorId': doctor.doctorId,
          'startAt': Timestamp.fromDate(start),
          'appointmentId': apptRef.id,
          'patientId': patient.patientId,
        });
        tx.set(apptRef, {
          'appointmentId': apptRef.id,
          'patientId': patient.patientId,
          'patientUid': patient.userUid,
          'patientName': patient.fullName,
          'patientPhone': patient.phone,
          'patientDateOfBirth': patient.dateOfBirth,
          'doctorId': doctor.doctorId,
          'doctorUid': doctor.userUid,
          'doctorName': doctor.fullName,
          'doctorSpecialization': doctor.specialization,
          'scheduleId': schedule.scheduleId,
          'reservationId': rid,
          'startAt': Timestamp.fromDate(start),
          'endAt': Timestamp.fromDate(end),
          'status': AppointmentStatus.scheduled.value,
          'bookedByUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _notify(
          tx,
          type: 'booked',
          appointmentId: apptRef.id,
          recipients: [patient.userUid, doctor.userUid],
          actorUid: uid,
          patientName: patient.fullName,
          doctorName: doctor.fullName,
          startAt: start,
        );
      });
    } on FirebaseException catch (e) {
      throw await _translateConflict(e, resvRef);
    }
    return apptRef.id;
  }

  // ---------------------------------------------------------------------------
  // cancelAtomically() — UC7
  // ---------------------------------------------------------------------------
  static Future<void> cancelAtomically(Appointment appointment) async {
    final uid = _uid;
    final apptRef = Repo.appointments.doc(appointment.appointmentId);
    await Repo.db.runTransaction((tx) async {
      final snap = await tx.get(apptRef);
      if (!snap.exists) throw AppException('err_not_found');
      final current = Appointment.fromDoc(snap);
      if (!current.isScheduled) throw AppException('err_invalid_state');
      tx.update(apptRef, {
        'status': AppointmentStatus.cancelled.value,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.delete(Repo.reservations.doc(current.reservationId)); // libère le créneau
      _notify(
        tx,
        type: 'cancelled',
        appointmentId: current.appointmentId,
        recipients: [current.patientUid, current.doctorUid],
        actorUid: uid,
        patientName: current.patientName,
        doctorName: current.doctorName,
        startAt: current.startAt,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // rescheduleAtomically() — UC8
  // ---------------------------------------------------------------------------
  static Future<void> rescheduleAtomically({
    required Appointment appointment,
    required Doctor doctor,
    required Slot newSlot,
  }) async {
    final uid = _uid;
    final start = newSlot.start.toUtc();
    final end = start.add(ClinicTime.slotDuration);
    final schedule = await _getSchedule(newSlot.scheduleId);
    _validateSlot(doctor, schedule, start);

    final apptRef = Repo.appointments.doc(appointment.appointmentId);
    final newRid = ClinicTime.reservationId(doctor.doctorId, start);
    final newResvRef = Repo.reservations.doc(newRid);

    try {
      await Repo.db.runTransaction((tx) async {
        final apptSnap = await tx.get(apptRef);
        if (!apptSnap.exists) throw AppException('err_not_found');
        final current = Appointment.fromDoc(apptSnap);
        if (!current.isScheduled) throw AppException('err_invalid_state');
        if (current.reservationId == newRid) throw AppException('err_same_slot');

        final taken = await tx.get(newResvRef);
        if (taken.exists) throw AppException('err_slot_taken');

        tx.set(newResvRef, {
          'doctorId': doctor.doctorId,
          'startAt': Timestamp.fromDate(start),
          'appointmentId': current.appointmentId,
          'patientId': current.patientId,
        });
        tx.update(apptRef, {
          'startAt': Timestamp.fromDate(start),
          'endAt': Timestamp.fromDate(end),
          'scheduleId': schedule.scheduleId,
          'reservationId': newRid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.delete(Repo.reservations.doc(current.reservationId)); // libère l'ancien créneau
        _notify(
          tx,
          type: 'rescheduled',
          appointmentId: current.appointmentId,
          recipients: [current.patientUid, current.doctorUid],
          actorUid: uid,
          patientName: current.patientName,
          doctorName: current.doctorName,
          startAt: start,
          oldStartAt: current.startAt,
        );
      });
    } on FirebaseException catch (e) {
      throw await _translateConflict(e, newResvRef);
    }
  }

  // ---------------------------------------------------------------------------
  // markCompleted() — UC13
  // ---------------------------------------------------------------------------
  static Future<void> markCompleted(Appointment appointment) async {
    final uid = _uid;
    final apptRef = Repo.appointments.doc(appointment.appointmentId);
    await Repo.db.runTransaction((tx) async {
      final snap = await tx.get(apptRef);
      if (!snap.exists) throw AppException('err_not_found');
      final current = Appointment.fromDoc(snap);
      if (!current.isScheduled) throw AppException('err_invalid_state');
      tx.update(apptRef, {
        'status': AppointmentStatus.completed.value,
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _notify(
        tx,
        type: 'completed',
        appointmentId: current.appointmentId,
        recipients: [current.patientUid],
        actorUid: uid,
        patientName: current.patientName,
        doctorName: current.doctorName,
        startAt: current.startAt,
      );
    });
  }

  /// Notifications in-app : écrites dans la MÊME transaction que le rendez-vous
  /// (le patient et le médecin concernés sont prévenus ; jamais l'auteur de l'action).
  static void _notify(
    Transaction tx, {
    required String type,
    required String appointmentId,
    required List<String?> recipients,
    required String actorUid,
    required String patientName,
    required String doctorName,
    required DateTime startAt,
    DateTime? oldStartAt,
  }) {
    final targets = recipients.whereType<String>().where((r) => r.isNotEmpty && r != actorUid).toSet();
    for (final recipient in targets) {
      tx.set(Repo.notifications.doc(), {
        'recipientUid': recipient,
        'actorUid': actorUid,
        'type': type,
        'appointmentId': appointmentId,
        'patientName': patientName,
        'doctorName': doctorName,
        'startAt': Timestamp.fromDate(startAt),
        if (oldStartAt != null) 'oldStartAt': Timestamp.fromDate(oldStartAt),
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Si le serveur refuse l'écriture alors que le créneau vient d'être pris
  /// par quelqu'un d'autre, on affiche "créneau déjà réservé".
  static Future<Object> _translateConflict(FirebaseException e, DocumentReference resvRef) async {
    if (e.code == 'permission-denied' || e.code == 'aborted' || e.code == 'already-exists') {
      try {
        final snap = await resvRef.get();
        if (snap.exists) return AppException('err_slot_taken');
      } catch (_) {
        // ignore : on retourne l'erreur d'origine
      }
    }
    return e;
  }
}
