import 'package:flutter/widgets.dart';

import 'strings.dart';

/// État global léger : langue choisie (FR / EN).
class AppState extends ChangeNotifier {
  AppState() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _lang = code == 'en' ? 'en' : 'fr';
  }

  String _lang = 'fr';
  String get lang => _lang;
  Locale get locale => Locale(_lang);

  void setLang(String code) {
    final next = code == 'en' ? 'en' : 'fr';
    if (next == _lang) return;
    _lang = next;
    notifyListeners();
  }

  void toggleLang() => setLang(_lang == 'fr' ? 'en' : 'fr');

  String translate(String key, [Map<String, String>? params]) {
    var text = Strings.data[_lang]?[key] ?? Strings.data['fr']?[key] ?? key;
    if (params != null) {
      params.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }
}

final AppState appState = AppState();

/// Rend la langue accessible partout et reconstruit l'interface
/// instantanément quand l'utilisateur bascule FR <-> EN.
class LangScope extends InheritedNotifier<AppState> {
  const LangScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LangScope>();
    return scope?.notifier ?? appState;
  }
}

extension TrContext on BuildContext {
  /// Traduction d'une clé : context.tr('login')
  String tr(String key, [Map<String, String>? params]) =>
      LangScope.of(this).translate(key, params);

  String get lang => LangScope.of(this).lang;
}
