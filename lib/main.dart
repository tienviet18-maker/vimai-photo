import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/locale_controller.dart';
import 'core/specs/spec_repository.dart';
import 'core/store/photo_store.dart';
import 'platform/photo_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    VimaiPhotoApp(
      localeController: LocaleController(prefs),
      specRepository: SpecRepository(),
      photoStore: PhotoStore(prefs, directory: const PhotoNative().appDir),
    ),
  );
}
