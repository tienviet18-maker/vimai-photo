import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/locale/locale_controller.dart';
import 'core/specs/spec_repository.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';

class VimaiPhotoApp extends StatelessWidget {
  const VimaiPhotoApp({
    super.key,
    required this.localeController,
    required this.specRepository,
  });

  final LocaleController localeController;
  final SpecRepository specRepository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: localeController.locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Unsupported device languages fall back to English.
        localeResolutionCallback: (device, supported) {
          if (device == null) return const Locale('en');
          return supported
                  .where((l) => l.languageCode == device.languageCode)
                  .firstOrNull ??
              const Locale('en');
        },
        home: HomeScreen(
          specRepository: specRepository,
          localeController: localeController,
        ),
      ),
    );
  }
}
