/// Constantes de l'application Clinova.
class AppInfo {
  AppInfo._();
  static const String name = 'Clinova';
  static const String clinicAddress = 'Djibouti';
}

/// Spécialités médicales (clé stockée en base, libellé traduit à l'affichage).
class Specializations {
  Specializations._();
  static const List<String> keys = [
    'general',
    'pediatrics',
    'cardiology',
    'gynecology',
    'dermatology',
    'ophthalmology',
    'ent',
    'dentistry',
    'orthopedics',
    'neurology',
    'psychiatry',
    'internal',
  ];

  /// Clé de traduction : spec_general, spec_pediatrics…
  static String trKey(String key) => 'spec_$key';
}

/// Comptes de démonstration (créés automatiquement lors de l'initialisation).
class DemoAccount {
  const DemoAccount({
    required this.role,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    this.doctorId,
    this.specialization,
  });

  final String role;
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final String? doctorId;
  final String? specialization;
}

class DemoData {
  DemoData._();

  static const DemoAccount admin = DemoAccount(
    role: 'admin',
    email: 'admin@clinova.demo',
    password: 'Admin123!',
    fullName: 'Admin Clinova',
    phone: '+253 77 00 00 01',
  );

  static const DemoAccount receptionist = DemoAccount(
    role: 'receptionist',
    email: 'reception@clinova.demo',
    password: 'Recep123!',
    fullName: 'Hodan Moussa',
    phone: '+253 77 00 00 02',
  );

  static const DemoAccount doctor1 = DemoAccount(
    role: 'doctor',
    email: 'dr.ahmed@clinova.demo',
    password: 'Doctor123!',
    fullName: 'Dr Ahmed Hassan',
    phone: '+253 77 00 00 03',
    doctorId: 'demo-dr-ahmed',
    specialization: 'general',
  );

  static const DemoAccount doctor2 = DemoAccount(
    role: 'doctor',
    email: 'dr.amina@clinova.demo',
    password: 'Doctor123!',
    fullName: 'Dr Amina Farah',
    phone: '+253 77 00 00 04',
    doctorId: 'demo-dr-amina',
    specialization: 'pediatrics',
  );

  static const DemoAccount patient = DemoAccount(
    role: 'patient',
    email: 'patient@clinova.demo',
    password: 'Patient123!',
    fullName: 'Fatouma Ali',
    phone: '+253 77 00 00 05',
  );

  /// Ordre d'affichage sur l'écran de connexion.
  static const List<DemoAccount> all = [patient, doctor1, receptionist, admin, doctor2];

  /// Horaires par défaut : samedi -> jeudi, 08:00-12:00 et 14:00-17:00.
  static const List<List<int>> defaultBlocks = [
    [8 * 60, 12 * 60],
    [14 * 60, 17 * 60],
  ];
}
