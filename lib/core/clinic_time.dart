/// Gestion de l'heure locale de la clinique (Djibouti, UTC+3, pas d'heure d'été).
///
/// Toutes les heures de rendez-vous sont calculées dans le fuseau de la clinique,
/// quel que soit le fuseau du téléphone ou de l'ordinateur de l'utilisateur.
/// Une "heure murale" (wall time) est représentée par un DateTime UTC dont les
/// champs (année, mois, jour, heure, minute) correspondent à l'heure de la clinique.
class ClinicTime {
  ClinicTime._();

  static const String timeZoneName = 'Africa/Djibouti (UTC+3)';
  static const Duration offset = Duration(hours: 3);

  /// Durée fixe d'un rendez-vous.
  static const int slotMinutes = 30;
  static const Duration slotDuration = Duration(minutes: slotMinutes);

  /// Vendredi : clinique fermée (DateTime.friday == 5).
  static const Set<int> closedWeekdays = {DateTime.friday};

  /// Ordre d'affichage de la semaine de travail : samedi -> jeudi.
  static const List<int> workWeekOrder = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ];

  /// Heure murale actuelle de la clinique.
  static DateTime nowWall() => DateTime.now().toUtc().add(offset);

  /// Convertit un instant réel en heure murale de la clinique.
  static DateTime toWall(DateTime instant) => instant.toUtc().add(offset);

  /// Convertit une heure murale de la clinique en instant réel (UTC).
  static DateTime fromWall(DateTime wall) => DateTime.utc(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      ).subtract(offset);

  /// Début de la journée (heure murale) pour une date murale.
  static DateTime wallDate(DateTime wall) =>
      DateTime.utc(wall.year, wall.month, wall.day);

  /// Bornes réelles [début, fin[ d'une journée de la clinique.
  static DateTime dayStartInstant(DateTime wallDay) =>
      fromWall(DateTime.utc(wallDay.year, wallDay.month, wallDay.day));

  static DateTime dayEndInstant(DateTime wallDay) =>
      dayStartInstant(wallDay).add(const Duration(days: 1));

  static bool isClosedDay(DateTime wallDay) =>
      closedWeekdays.contains(wallDay.weekday);

  static bool sameWallDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "08:30" <-> 510
  static String minutesToHHmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int hhmmToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Identifiant déterministe de réservation : doctorId_startMillis.
  static String reservationId(String doctorId, DateTime startInstant) =>
      '${doctorId}_${startInstant.toUtc().millisecondsSinceEpoch}';
}
