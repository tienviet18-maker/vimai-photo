import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.localeController});

  final LocaleController localeController;

  /// Each language is shown in its own script so anyone can find theirs.
  static const _nativeNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'ja': '日本語',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          final current = localeController.locale?.languageCode;
          return RadioGroup<String?>(
            groupValue: current,
            onChanged: (code) => localeController
                .setLocale(code == null ? null : Locale(code)),
            child: ListView(
              children: [
                ListTile(
                  title: Text(
                    l.languageLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                RadioListTile<String?>(
                  value: null,
                  title: Text(l.languageSystem),
                ),
                for (final locale in LocaleController.supported)
                  RadioListTile<String?>(
                    value: locale.languageCode,
                    title: Text(_nativeNames[locale.languageCode]!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
