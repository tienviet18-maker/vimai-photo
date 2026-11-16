import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimai_photo/app.dart';
import 'package:vimai_photo/core/locale/locale_controller.dart';
import 'package:vimai_photo/core/specs/spec_repository.dart';
import 'package:vimai_photo/core/store/photo_store.dart';

/// Serves the real spec file synchronously, so no real I/O has to finish
/// inside the test's fake-async zone.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()));

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture(File(key).readAsStringSync());
}

Future<void> _pumpApp(WidgetTester tester, {String? locale}) async {
  SharedPreferences.setMockInitialValues(
    locale == null ? {} : {'locale': locale},
  );
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    VimaiPhotoApp(
      localeController: LocaleController(prefs),
      specRepository: SpecRepository(bundle: _FileBundle()),
      photoStore: PhotoStore(prefs, directory: () async => Directory.systemTemp.path),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home lists documents in Vietnamese with the Japanese name',
      (tester) async {
    await _pumpApp(tester, locale: 'vi');
    expect(find.text('Bạn cần ảnh cho giấy tờ nào?'), findsOneWidget);
    expect(find.text('Thẻ cư trú / gia hạn, đổi visa'), findsOneWidget);
    expect(find.text('在留カード・在留申請'), findsOneWidget);
  });

  testWidgets('Japanese UI does not repeat the Japanese name', (tester) async {
    await _pumpApp(tester, locale: 'ja');
    expect(find.text('どの書類の写真ですか？'), findsOneWidget);
    expect(find.text('在留カード・在留申請'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await _pumpApp(tester, locale: 'en');
    await tester.enterText(find.byType(TextField), 'passport');
    await tester.pumpAndSettle();
    expect(find.text('Japanese passport'), findsOneWidget);
    expect(find.text('My Number card'), findsNothing);
  });

  testWidgets('tapping a document opens its rules', (tester) async {
    await _pumpApp(tester, locale: 'en');
    await tester.tap(find.text('Residence card / visa application'));
    await tester.pumpAndSettle();
    expect(find.text('No hat'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);
    // The capture button sits below the fold on the 800x600 test screen.
    await tester.scrollUntilVisible(find.text('Take photo'), 200);
    expect(find.text('Take photo'), findsOneWidget);
  });

  testWidgets('bottom bar opens My photos and How to print', (tester) async {
    await _pumpApp(tester, locale: 'en');
    await tester.tap(find.text('My photos').last);
    await tester.pumpAndSettle();
    expect(find.text('No photos yet. Photos you save appear here.'), findsOneWidget);
    await tester.tap(find.text('How to print').last);
    await tester.pumpAndSettle();
    expect(find.text('Open the store\'s print app'), findsOneWidget);
  });
}
