// Ajuste le projet Android généré par `flutter create` pour Clinova :
//  * nom affiché "Clinova"
//  * permission INTERNET (obligatoire pour Firebase en mode release)
//  * minSdk >= 23 (exigé par Firebase Auth)
//
// Usage (depuis la racine du projet) :  dart run tool/patch_android.dart
// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  var ok = true;
  ok &= _patchManifest();
  ok &= _patchGradle();
  print(ok ? '\n✅ Android prêt pour Clinova.' : '\n⚠️  Vérifiez les messages ci-dessus.');
}

bool _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    print('❌ ${file.path} introuvable. Lancez d\'abord : flutter create . --platforms=android,web');
    return false;
  }
  final original = file.readAsStringSync();
  var xml = original.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Clinova"');

  if (!xml.contains('android.permission.INTERNET')) {
    final tag = RegExp(r'<manifest[^>]*>').firstMatch(xml);
    if (tag != null) {
      xml = xml.replaceRange(
        tag.end,
        tag.end,
        '\n    <uses-permission android:name="android.permission.INTERNET"/>',
      );
    }
  }

  if (xml != original) {
    file.writeAsStringSync(xml);
    print('✔ AndroidManifest.xml : nom "Clinova" + permission INTERNET');
  } else {
    print('✔ AndroidManifest.xml déjà à jour');
  }
  return true;
}

bool _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    final before = s;
    s = s.replaceAll(
      RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'),
      'minSdk = maxOf(23, flutter.minSdkVersion)',
    );
    s = s.replaceAllMapped(RegExp(r'minSdk\s*=\s*(\d+)'), (m) {
      final v = int.parse(m.group(1)!);
      return 'minSdk = ${v < 23 ? 23 : v}';
    });
    if (s != before) kts.writeAsStringSync(s);
    print('✔ build.gradle.kts : minSdk >= 23');
    return true;
  }
  if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    final before = s;
    s = s.replaceAll(
      RegExp(r'minSdkVersion\s+flutter\.minSdkVersion'),
      'minSdkVersion Math.max(23, flutter.minSdkVersion)',
    );
    s = s.replaceAll(
      RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'),
      'minSdk = Math.max(23, flutter.minSdkVersion)',
    );
    s = s.replaceAllMapped(RegExp(r'minSdkVersion\s+(\d+)'), (m) {
      final v = int.parse(m.group(1)!);
      return 'minSdkVersion ${v < 23 ? 23 : v}';
    });
    if (s != before) groovy.writeAsStringSync(s);
    print('✔ build.gradle : minSdk >= 23');
    return true;
  }
  print('❌ android/app/build.gradle(.kts) introuvable.');
  return false;
}
