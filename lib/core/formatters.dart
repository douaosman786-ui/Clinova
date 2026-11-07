import 'clinic_time.dart';

/// Formatage des dates sans dépendance externe (FR / EN), en heure de la clinique.
class Fmt {
  Fmt._();

  static const _daysFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _shortDaysFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  static const _shortDaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthsFr = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _shortMonthsFr = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  static const _shortMonthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String weekdayName(int weekday, String lang) =>
      (lang == 'en' ? _daysEn : _daysFr)[weekday - 1];

  static String weekdayCap(int weekday, String lang) {
    final n = weekdayName(weekday, lang);
    return n[0].toUpperCase() + n.substring(1);
  }

  static String shortWeekday(int weekday, String lang) =>
      (lang == 'en' ? _shortDaysEn : _shortDaysFr)[weekday - 1];

  static String shortMonth(int month, String lang) =>
      (lang == 'en' ? _shortMonthsEn : _shortMonthsFr)[month - 1];

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Heure "14:30" d'un instant réel, en heure de la clinique.
  static String time(DateTime instant) {
    final w = ClinicTime.toWall(instant);
    return '${_two(w.hour)}:${_two(w.minute)}';
  }

  /// Date longue d'une date murale : "samedi 7 novembre 2026" / "Saturday, November 7, 2026"
  static String longWallDate(DateTime wall, String lang) {
    if (lang == 'en') {
      return '${_daysEn[wall.weekday - 1]}, ${_monthsEn[wall.month - 1]} ${wall.day}, ${wall.year}';
    }
    return '${_daysFr[wall.weekday - 1]} ${wall.day} ${_monthsFr[wall.month - 1]} ${wall.year}';
  }

  static String longDate(DateTime instant, String lang) =>
      longWallDate(ClinicTime.toWall(instant), lang);

  /// "sam. 7 nov. 2026 · 08:30"
  static String dateTime(DateTime instant, String lang) {
    final w = ClinicTime.toWall(instant);
    final day = shortWeekday(w.weekday, lang);
    final month = shortMonth(w.month, lang);
    final datePart = lang == 'en'
        ? '$day, $month ${w.day}, ${w.year}'
        : '$day ${w.day} $month ${w.year}';
    return '$datePart · ${_two(w.hour)}:${_two(w.minute)}';
  }

  /// Date simple JJ/MM/AAAA pour un DateTime "calendrier" (date de naissance).
  static String simpleDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// Date ISO AAAA-MM-JJ
  static String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
}
