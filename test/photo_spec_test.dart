import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/specs/photo_spec.dart';
import 'package:vimai_photo/core/specs/spec_repository.dart';

void main() {
  final raw = File('assets/specs/photo_specs.json').readAsStringSync();

  group('mmToPx', () {
    test('converts at 300 dpi', () {
      expect(mmToPx(25.4), 300);
      expect(mmToPx(40), 472);
      expect(mmToPx(30), 354);
    });

    test('L-size sheet is 1051 x 1500 px', () {
      expect(mmToPx(89), 1051);
      expect(mmToPx(127), 1500);
    });
  });

  group('photo_specs.json', () {
    final all = SpecRepository.parse(raw, includeUnverified: true);

    test('parses every spec with unique ids', () {
      expect(all, isNotEmpty);
      expect(all.map((s) => s.id).toSet().length, all.length);
    });

    test('every spec has en, vi and ja names', () {
      for (final s in all) {
        expect(s.names.keys, containsAll(<String>['en', 'vi', 'ja']), reason: s.id);
      }
    });

    test('verified specs cite a source unless explicitly de-facto', () {
      for (final s in all.where((s) => s.verified && s.id != 'jp_resume')) {
        expect(s.sourceUrl, isNotNull, reason: s.id);
      }
    });

    test('release mode hides unverified specs', () {
      final release = SpecRepository.parse(raw, includeUnverified: false);
      expect(release.every((s) => s.verified), isTrue);
      expect(release.length, lessThan(all.length));
    });

    test('official sizes match the sources checked on 2026-11-15', () {
      PhotoSpec byId(String id) => all.firstWhere((s) => s.id == id);
      expect((byId('jp_residence').heightMm, byId('jp_residence').widthMm), (40, 30));
      expect(byId('jp_residence').validityMonths, 6);
      expect((byId('jp_mynumber').heightMm, byId('jp_mynumber').widthMm), (45, 35));
      expect((byId('jp_passport').heightMm, byId('jp_passport').widthMm), (45, 35));
      expect(byId('jp_passport').headHeightMm, 34);
      expect(
        (byId('jp_driver_license').heightMm, byId('jp_driver_license').widthMm),
        (30, 24),
      );
    });

    test('free tier includes the residence card', () {
      expect(all.firstWhere((s) => s.id == 'jp_residence').pro, isFalse);
    });
  });

  test('rejects unknown rule ids', () {
    expect(() => PhotoRule.fromId('smile'), throwsFormatException);
  });
}
