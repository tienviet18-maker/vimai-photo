import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's language choice. `null` means "same as device".
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : _locale = _read(_prefs);

  /// Ordered by how many residents of Japan speak them.
  static const supported = [
    Locale('vi'),
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ko'),
    Locale('fil'),
    Locale('ne'),
    Locale('pt'),
    Locale('id'),
    Locale('my'),
    Locale('th'),
    Locale('si'),
  ];

  /// Each language in its own script, so anyone can find theirs.
  static const nativeNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'ja': '日本語',
    'zh': '简体中文',
    'zh-Hant': '繁體中文',
    'ko': '한국어',
    'fil': 'Filipino',
    'ne': 'नेपाली',
    'pt': 'Português (Brasil)',
    'id': 'Bahasa Indonesia',
    'my': 'မြန်မာ',
    'th': 'ไทย',
    'si': 'සිංහල',
  };

  static const _key = 'locale';

  final SharedPreferences _prefs;
  Locale? _locale;

  Locale? get locale => _locale;

  static Locale? _read(SharedPreferences prefs) {
    final tag = prefs.getString(_key);
    if (tag == null) return null;
    return supported.where((l) => l.toLanguageTag() == tag).firstOrNull;
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == _locale) return;
    _locale = locale;
    if (locale == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, locale.toLanguageTag());
    }
    notifyListeners();
  }
}

/// The app language for a device language; English when we have none.
/// Chinese in Taiwan, Hong Kong and Macau, or written in Hant, gets
/// Traditional; Tagalog gets Filipino.
Locale resolveAppLocale(Locale? device) {
  if (device == null) return const Locale('en');
  final code = device.languageCode == 'tl' ? 'fil' : device.languageCode;
  if (code == 'zh') {
    final traditional = device.scriptCode == 'Hant' ||
        const {'TW', 'HK', 'MO'}.contains(device.countryCode);
    return traditional
        ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
        : const Locale('zh');
  }
  return LocaleController.supported
          .where((l) => l.languageCode == code && l.scriptCode == null)
          .firstOrNull ??
      const Locale('en');
}

/// The app language as a short tag: 'vi', 'en', 'zh', 'zh-Hant', ...
/// Data keyed by language (document names) uses this tag.
String langOf(BuildContext context) {
  final l = Localizations.localeOf(context);
  return l.languageCode == 'zh' && l.scriptCode == 'Hant' ? 'zh-Hant' : l.languageCode;
}
