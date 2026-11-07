import 'package:firebase_auth/firebase_auth.dart';

/// Erreur métier portant une clé de traduction (affichée en FR ou EN).
class AppException implements Exception {
  AppException(this.key);
  final String key;

  @override
  String toString() => 'AppException($key)';
}

/// Convertit toute erreur en clé de traduction "sûre" pour l'utilisateur.
String errorKey(Object error) {
  if (error is AppException) return error.key;
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'err_invalid_email';
      case 'user-disabled':
        return 'err_account_disabled';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'err_wrong_credentials';
      case 'email-already-in-use':
        return 'err_email_in_use';
      case 'weak-password':
        return 'err_weak_password';
      case 'too-many-requests':
        return 'err_too_many_requests';
      case 'network-request-failed':
        return 'err_network';
      case 'operation-not-allowed':
      case 'configuration-not-found':
      case 'admin-restricted-operation':
        return 'err_auth_not_enabled';
      default:
        return 'err_generic';
    }
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'err_permission';
      case 'unavailable':
        return 'err_network';
      case 'failed-precondition':
        return 'err_precondition';
      case 'aborted':
        return 'err_slot_taken';
      case 'not-found':
        return 'err_not_found';
      default:
        return 'err_generic';
    }
  }
  return 'err_generic';
}
