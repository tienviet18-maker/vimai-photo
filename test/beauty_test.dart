import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/photo/beauty.dart';
import 'package:vimai_photo/core/photo/review_checks.dart';

void main() {
  test('passports and licences start with no beauty, CV the most', () {
    expect(defaultBeautyFor(EditLevel.strict).isNone, isTrue);
    final cv = defaultBeautyFor(EditLevel.cv);
    final std = defaultBeautyFor(EditLevel.standard);
    expect(std.isNone, isFalse);
    expect(cv.smooth, greaterThan(std.smooth));
    expect(cv.brighten, greaterThan(std.brighten));
    expect(std.lips, 0, reason: 'lip colour only by choice on official documents');
  });

  test('values stay within 0…1 and round-trip to the native map', () {
    for (final level in EditLevel.values) {
      final m = defaultBeautyFor(level).toMap();
      expect(m.keys, containsAll(['smooth', 'brighten', 'even', 'shine', 'sharpen', 'lips']));
      for (final v in m.values) {
        expect(v, inInclusiveRange(0, 1));
      }
    }
  });
}
