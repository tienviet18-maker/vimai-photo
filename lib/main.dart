import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/locale_controller.dart';
import 'core/specs/spec_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    VimaiPhotoApp(
      localeController: LocaleController(prefs),
      specRepository: SpecRepository(),
    ),
  );
}
