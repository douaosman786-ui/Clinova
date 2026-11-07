import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/clinic_time.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'repo.dart';

/// Initialisation de Clinova et comptes de démonstration (un par rôle).
class DemoService {
  DemoService._();

  /// La base a-t-elle déjà été initialisée (premier administrateur créé) ?
  static Future<bool> isInitialized() async {
    final doc = await Repo.bootstrapDoc.get();
    return doc.exists;
  }

  /// Première exécution : crée l'administrateur de démonstration, verrouille
  /// l'initialisation (config/bootstrap), puis crée les autres comptes démo.
  static Future<void> initialize({void Function(String step)? onStep}) async {
    final auth = FirebaseAuth.instance;
    const admin = DemoData.admin;

    onStep?.call('setup_step_admin');
    UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(email: admin.email, password: admin.password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      cred = await auth.signInWithEmailAndPassword(email: admin.email, password: admin.password);
    }
    final adminUid = cred.user!.uid;

    final already = await isInitialized();
    if (!already) {
      final batch = Repo.db.batch();
      batch.set(Repo.users.doc(adminUid), {
        'uid': adminUid,
        'fullName': admin.fullName,
        'email': admin.email,
        'phone': admin.phone,
        'role': UserRole.administrator.value,
        'isActive': true,
        'language': 'fr',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(Repo.bootstrapDoc, {
        'adminUid': adminUid,
        'clinicName': AppInfo.name,
        'timeZone': ClinicTime.timeZoneName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }

    await ensureDemoAccounts(onStep: onStep);
    await auth.signOut();
  }

  /// Crée (ou recrée) les comptes démo. Doit être appelé par un administrateur.
  static Future<void> ensureDemoAccounts({void Function(String step)? onStep}) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Médecins + horaires (samedi -> jeudi, 08:00-12:00 et 14:00-17:00)
    for (final d in [DemoData.doctor1, DemoData.doctor2]) {
      onStep?.call('setup_step_doctors');
      final uid = await AccountService.createAuthAccount(
        email: d.email,
        password: d.password,
        reuseExisting: true,
      );
      final batch = Repo.db.batch();
      batch.set(Repo.doctors.doc(d.doctorId), {
        'doctorId': d.doctorId,
        'fullName': d.fullName,
        'specialization': d.specialization,
        'phone': d.phone,
        'email': d.email,
        'userUid': uid,
        'isActive': true,
        'createdByUid': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(Repo.users.doc(uid), {
        'uid': uid,
        'fullName': d.fullName,
        'email': d.email,
        'phone': d.phone,
        'role': UserRole.doctor.value,
        'doctorId': d.doctorId,
        'isActive': true,
        'language': 'fr',
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final day in ClinicTime.workWeekOrder) {
        for (var i = 0; i < DemoData.defaultBlocks.length; i++) {
          final block = DemoData.defaultBlocks[i];
          batch.set(
            Repo.schedules.doc('${d.doctorId}-d$day-b$i'),
            DoctorSchedule.toMap(
              doctorId: d.doctorId!,
              dayOfWeek: day,
              startMinutes: block[0],
              endMinutes: block[1],
              isAvailable: true,
            ),
          );
        }
      }
      await batch.commit();
    }

    // Administrateur démo : réactivé s'il avait été désactivé (sauf si c'est
    // le compte actuellement connecté, qui est forcément déjà actif).
    const da = DemoData.admin;
    final daUid = await AccountService.createAuthAccount(
      email: da.email,
      password: da.password,
      reuseExisting: true,
    );
    if (daUid != adminUid) {
      await Repo.users.doc(daUid).set({
        'uid': daUid,
        'fullName': da.fullName,
        'email': da.email,
        'phone': da.phone,
        'role': UserRole.administrator.value,
        'isActive': true,
        'language': 'fr',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Réceptionniste
    onStep?.call('setup_step_staff');
    const r = DemoData.receptionist;
    final rUid = await AccountService.createAuthAccount(
      email: r.email,
      password: r.password,
      reuseExisting: true,
    );
    await Repo.users.doc(rUid).set({
      'uid': rUid,
      'fullName': r.fullName,
      'email': r.email,
      'phone': r.phone,
      'role': UserRole.receptionist.value,
      'isActive': true,
      'language': 'fr',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Patient
    onStep?.call('setup_step_patient');
    const p = DemoData.patient;
    final pUid = await AccountService.createAuthAccount(
      email: p.email,
      password: p.password,
      reuseExisting: true,
    );
    await AuthService.writePatientAccountDocs(
      uid: pUid,
      fullName: p.fullName,
      email: p.email,
      phone: p.phone,
      dateOfBirth: '1995-04-12',
      createdByUid: adminUid,
    );
  }
}
