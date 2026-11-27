import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimai_photo/core/store/photo_store.dart';
import 'package:vimai_photo/features/done/done_screen.dart';

void main() {
  group('expiry', () {
    test('adds months and keeps the day', () {
      expect(expiryOf(DateTime(2026, 11, 15), 6), DateTime(2027, 5, 15));
      expect(expiryOf(DateTime(2026, 6, 2), 3), DateTime(2026, 9, 2));
    });

    test('clamps to the last day of a shorter month', () {
      expect(expiryOf(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(expiryOf(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
    });

    test('status: valid, soon within 30 days, expired after the day', () {
      final expiry = DateTime(2027, 5, 15);
      expect(expiryStatus(expiry, DateTime(2027, 1, 1)), ExpiryStatus.valid);
      expect(expiryStatus(expiry, DateTime(2027, 4, 20)), ExpiryStatus.soon);
      expect(expiryStatus(expiry, DateTime(2027, 5, 15, 23)), ExpiryStatus.soon);
      expect(expiryStatus(expiry, DateTime(2027, 5, 16)), ExpiryStatus.expired);
    });

    test('whole months left', () {
      final expiry = DateTime(2027, 5, 15);
      expect(monthsLeft(expiry, DateTime(2026, 11, 15)), 6);
      expect(monthsLeft(expiry, DateTime(2026, 11, 16)), 5);
      expect(monthsLeft(expiry, DateTime(2027, 6, 1)), 0);
    });

    test('reminder two weeks early, or on the day when that has passed', () {
      final expiry = DateTime(2027, 5, 15);
      expect(reminderDateFor(expiry, DateTime(2026, 11, 15)), DateTime(2027, 5, 1, 10));
      expect(reminderDateFor(expiry, DateTime(2027, 5, 10)), DateTime(2027, 5, 15, 10));
    });
  });

  group('PhotoStore', () {
    late Directory dir;
    late File photo;
    late File source;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vimai-store');
      photo = File('${dir.path}/in-photo.jpg')..writeAsBytesSync([1, 2, 3]);
      source = File('${dir.path}/in-source.heic')..writeAsBytesSync([4, 5]);
    });

    tearDown(() => dir.delete(recursive: true));

    Future<PhotoStore> open() async {
      final prefs = await SharedPreferences.getInstance();
      return PhotoStore(prefs, directory: () async => dir.path);
    }

    test('adds copies, survives a restart, removes files', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await open();
      final saved = await store.add(
        specId: 'jp_residence',
        photoPath: photo.path,
        sourcePath: source.path,
        takenAt: DateTime(2026, 11, 15),
      );
      expect(File(await store.pathOf(saved.photoFile)).readAsBytesSync(), [1, 2, 3]);
      expect(saved.sourceFile, endsWith('.heic'));

      final again = await open();
      expect(again.items.single.specId, 'jp_residence');
      expect(again.items.single.takenAt, DateTime(2026, 11, 15));

      await again.update(again.items.single.copyWith(remind: true));
      expect((await open()).items.single.remind, isTrue);

      await again.remove(again.items.single);
      expect(again.items, isEmpty);
      expect(File(await again.pathOf(saved.photoFile)).existsSync(), isFalse);
      expect(File(await again.pathOf(saved.sourceFile!)).existsSync(), isFalse);
    });

    test('newest first', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await open();
      await store.add(specId: 'a', photoPath: photo.path, takenAt: DateTime(2026, 1, 1));
      await store.add(specId: 'b', photoPath: photo.path, takenAt: DateTime(2026, 6, 1));
      expect((await open()).items.map((p) => p.specId), ['b', 'a']);
    });

    test('ignores a corrupt list instead of crashing', () async {
      SharedPreferences.setMockInitialValues({'photos': 'not json'});
      expect((await open()).items, isEmpty);
    });
  });
}
