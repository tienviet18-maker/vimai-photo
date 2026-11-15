import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/layout/print_sheet_layout.dart';
import 'package:vimai_photo/core/specs/photo_spec.dart';

PhotoSpec _spec(double h, double w) => PhotoSpec(
      id: 'test',
      names: const {'en': 'Test'},
      jaName: 'テスト',
      icon: 'badge',
      heightMm: h,
      widthMm: w,
      backgrounds: const [PhotoBackground.white],
      validityMonths: 6,
      rules: const [],
      pro: false,
      verified: true,
    );

void main() {
  // L size 89 x 127 mm, 3 mm margin, 2 mm gap.
  test('40x30 turns the sheet sideways to fit 6 instead of 4', () {
    final layout = PrintSheetLayout.grid(spec: _spec(40, 30));
    // sideways usable 121 x 83: (121+2)/32 -> 3 cols, (83+2)/42 -> 2 rows
    expect(layout.landscape, isTrue);
    expect((layout.columns, layout.rows), (3, 2));
    expect(layout.count, 6);
  });

  test('30x24 driver licence stays upright with 3 x 3', () {
    final layout = PrintSheetLayout.grid(spec: _spec(30, 24));
    // upright 9 beats sideways 4 x 2 = 8
    expect(layout.landscape, isFalse);
    expect(layout.count, 9);
  });

  test('45x35 fits 4 upright', () {
    final layout = PrintSheetLayout.grid(spec: _spec(45, 35));
    expect(layout.landscape, isFalse);
    expect(layout.count, 4);
  });

  test('grid is centred and stays inside the printable margin', () {
    for (final spec in [_spec(40, 30), _spec(45, 35), _spec(30, 24)]) {
      final layout = PrintSheetLayout.grid(spec: spec);
      final sheet = layout.sheet;
      for (final slot in layout.slots) {
        expect(slot.leftMm, greaterThanOrEqualTo(3));
        expect(slot.topMm, greaterThanOrEqualTo(3));
        expect(slot.leftMm + spec.widthMm, lessThanOrEqualTo(sheet.widthMm - 3));
        expect(slot.topMm + spec.heightMm, lessThanOrEqualTo(sheet.heightMm - 3));
      }
      final first = layout.slots.first;
      final last = layout.slots.last;
      expect(
        first.leftMm,
        closeTo(sheet.widthMm - (last.leftMm + spec.widthMm), 1e-9),
      );
      expect(
        first.topMm,
        closeTo(sheet.heightMm - (last.topMm + spec.heightMm), 1e-9),
      );
    }
  });

  test('photo larger than the sheet gives an empty layout', () {
    expect(PrintSheetLayout.grid(spec: _spec(200, 30)).count, 0);
  });
}
