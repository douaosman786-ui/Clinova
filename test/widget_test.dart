// Tests unitaires (sans Firebase) des règles de rendez-vous de Clinova.
// Lancer :  flutter test
import 'package:clinova/core/clinic_time.dart';
import 'package:clinova/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Heure de la clinique (Djibouti, UTC+3)', () {
    test('08:00 heure clinique = 05:00 UTC', () {
      final instant = ClinicTime.fromWall(DateTime.utc(2026, 11, 7, 8, 0));
      expect(instant, DateTime.utc(2026, 11, 7, 5, 0));
      expect(ClinicTime.toWall(instant).hour, 8);
    });

    test('Le vendredi est fermé, le samedi est ouvert', () {
      expect(ClinicTime.isClosedDay(DateTime.utc(2026, 11, 6)), isTrue); // vendredi
      expect(ClinicTime.isClosedDay(DateTime.utc(2026, 11, 7)), isFalse); // samedi
      expect(ClinicTime.workWeekOrder.contains(DateTime.friday), isFalse);
    });

    test('Un rendez-vous dure exactement 30 minutes', () {
      expect(ClinicTime.slotDuration, const Duration(minutes: 30));
    });

    test('Clé de réservation déterministe doctorId_startMillis', () {
      final start = ClinicTime.fromWall(DateTime.utc(2026, 11, 7, 8, 30));
      final id = ClinicTime.reservationId('demo-dr-ahmed', start);
      expect(id, 'demo-dr-ahmed_${start.millisecondsSinceEpoch}');
      // Les créneaux sont alignés sur 30 minutes (vérifié aussi par les règles Firestore).
      expect(start.millisecondsSinceEpoch % 1800000, 0);
    });

    test('Calcul du jour de la semaine identique aux règles Firestore', () {
      // Formule utilisée dans firestore.rules : ((floor(ms/86400000) + 3) % 7) + 1
      for (var d = 0; d < 14; d++) {
        final wall = DateTime.utc(2026, 11, 1 + d, 9);
        final localMs = ClinicTime.fromWall(wall).millisecondsSinceEpoch + 10800000;
        final weekday = ((localMs ~/ 86400000) + 3) % 7 + 1;
        expect(weekday, wall.weekday);
      }
    });

    test('Conversion HH:mm <-> minutes', () {
      expect(ClinicTime.minutesToHHmm(14 * 60 + 30), '14:30');
      expect(ClinicTime.hhmmToMinutes('08:00'), 480);
    });
  });

  test('Toutes les traductions existent en FR et en EN', () {
    final fr = Strings.data['fr']!.keys.toSet();
    final en = Strings.data['en']!.keys.toSet();
    expect(fr.difference(en), isEmpty);
    expect(en.difference(fr), isEmpty);
  });
}
