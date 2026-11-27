import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/locale/locale_controller.dart';

void main() {
  test('device languages map to app languages', () {
    expect(resolveAppLocale(const Locale('vi', 'VN')), const Locale('vi'));
    expect(resolveAppLocale(const Locale('ne', 'NP')), const Locale('ne'));
    expect(resolveAppLocale(const Locale('tl')), const Locale('fil'));
    expect(resolveAppLocale(const Locale('pt', 'BR')), const Locale('pt'));
    expect(resolveAppLocale(const Locale('de')), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });

  test('Chinese picks Simplified or Traditional', () {
    const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    expect(resolveAppLocale(const Locale('zh', 'CN')), const Locale('zh'));
    expect(resolveAppLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'JP')),
        const Locale('zh'));
    expect(resolveAppLocale(const Locale('zh', 'TW')), hant);
    expect(resolveAppLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'JP')), hant);
  });

  test('every supported language has a native name', () {
    for (final l in LocaleController.supported) {
      expect(LocaleController.nativeNames[l.toLanguageTag()], isNotNull, reason: l.toLanguageTag());
    }
  });
}
