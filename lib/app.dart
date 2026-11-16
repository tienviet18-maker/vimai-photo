import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/locale/locale_controller.dart';
import 'core/specs/spec_repository.dart';
import 'core/store/photo_store.dart';
import 'core/theme.dart';
import 'features/shell/app_shell.dart';
import 'l10n/app_localizations.dart';

class VimaiPhotoApp extends StatelessWidget {
  const VimaiPhotoApp({
    super.key,
    required this.localeController,
    required this.specRepository,
    required this.photoStore,
  });

  final LocaleController localeController;
  final SpecRepository specRepository;
  final PhotoStore photoStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.light,
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
        builder: (context, child) => PhotoStoreScope(store: photoStore, child: child!),
        home: AppShell(
          specRepository: specRepository,
          localeController: localeController,
        ),
      ),
    );
  }
}
