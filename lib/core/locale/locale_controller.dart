import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's language choice. `null` means "same as device".
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : _locale = _read(_prefs);

  static const supported = [Locale('vi'), Locale('en'), Locale('ja')];
  static const _key = 'locale';

  final SharedPreferences _prefs;
  Locale? _locale;

  Locale? get locale => _locale;

  static Locale? _read(SharedPreferences prefs) {
    final code = prefs.getString(_key);
    if (code == null) return null;
    return supported.where((l) => l.languageCode == code).firstOrNull;
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == _locale) return;
    _locale = locale;
    if (locale == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, locale.languageCode);
    }
    notifyListeners();
  }
}
