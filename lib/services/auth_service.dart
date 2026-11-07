import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/errors.dart';
import '../models/models.dart';
import 'repo.dart';

/// Authentification (UC1 Register, UC2 Log In) et gestion des comptes.
class AuthService {
  AuthService._();

  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Stream<User?> authChanges() => auth.authStateChanges();

  static Stream<UserProfile?> profileStream(String uid) => Repo.users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserProfile.fromDoc(d) : null);

  static Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  static Future<void> signOut() => auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  /// Changer son mot de passe : on revérifie d'abord le mot de passe actuel
  /// (Firebase l'exige pour les opérations sensibles).
  static Future<void> changePassword({required String current, required String next}) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw AppException('err_not_signed_in');
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
        throw AppException('err_wrong_current_password');
      }
      rethrow;
    }
    await user.updatePassword(next);
  }

  /// UC1 — inscription d'un patient : compte Auth + users/{uid} + patients/{uid}.
  static Future<void> registerPatient({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? dateOfBirth,
    required String language,
  }) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    try {
      await writePatientAccountDocs(
        uid: uid,
        fullName: fullName,
        email: email,
        phone: phone,
        dateOfBirth: dateOfBirth,
        createdByUid: uid,
        language: language,
      );
    } catch (e) {
      // Échec de création du profil : on supprime le compte pour permettre de recommencer.
      try {
        await cred.user!.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Écrit users/{uid} (rôle Patient) et patients/{uid} dans un même lot atomique.
  static Future<void> writePatientAccountDocs({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    String? dateOfBirth,
    required String createdByUid,
    String language = 'fr',
  }) async {
    final batch = Repo.db.batch();
    batch.set(Repo.users.doc(uid), {
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'role': UserRole.patient.value,
      'isActive': true,
      'patientId': uid,
      'language': language,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(Repo.patients.doc(uid), {
      'patientId': uid,
      'userUid': uid,
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'dateOfBirth': dateOfBirth,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> updateOwnProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) async {
    await Repo.users.doc(uid).update({
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> saveLanguage(String uid, String lang) async {
    try {
      await Repo.users.doc(uid).update({'language': lang});
    } catch (_) {
      // La préférence de langue n'est pas critique.
    }
  }
}

/// Création de comptes Firebase Auth pour d'autres personnes (médecins,
/// réceptionnistes, patients) sans déconnecter l'utilisateur actuel :
/// on utilise une seconde instance Firebase ("app secondaire").
class AccountService {
  AccountService._();

  static const _secondaryName = 'clinova-secondary';

  static Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp? app;
    for (final a in Firebase.apps) {
      if (a.name == _secondaryName) app = a;
    }
    app ??= await Firebase.initializeApp(name: _secondaryName, options: Firebase.app().options);
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Crée le compte et renvoie son UID. Si [reuseExisting] est vrai et que
  /// l'e-mail existe déjà, on tente de s'y connecter avec le même mot de passe
  /// (utile pour réinitialiser les comptes de démonstration).
  static Future<String> createAuthAccount({
    required String email,
    required String password,
    bool reuseExisting = false,
  }) async {
    final secondary = await _secondaryAuth();
    try {
      final cred = await secondary.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (reuseExisting && e.code == 'email-already-in-use') {
        try {
          final cred = await secondary.signInWithEmailAndPassword(email: email.trim(), password: password);
          return cred.user!.uid;
        } on FirebaseAuthException {
          throw AppException('err_demo_password_changed');
        }
      }
      rethrow;
    } finally {
      try {
        await secondary.signOut();
      } catch (_) {}
    }
  }
}
