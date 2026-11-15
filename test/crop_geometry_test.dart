import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/capture/face_metrics.dart';
import 'package:vimai_photo/core/photo/crop_geometry.dart';
import 'package:vimai_photo/core/photo/photo_analysis.dart';
import 'package:vimai_photo/core/photo/review_checks.dart';
import 'package:vimai_photo/core/specs/photo_spec.dart';

PhotoSpec _spec({
  String id = 'test',
  double h = 40,
  double w = 30,
  double? head,
  double? tol,
  double? top,
  List<PhotoRule> rules = const [PhotoRule.onlyYou],
}) =>
    PhotoSpec(
      id: id,
      names: const {'en': 'Test'},
      jaName: 'テスト',
      icon: 'badge',
      heightMm: h,
      widthMm: w,
      headHeightMm: head,
      headToleranceMm: tol,
      topMarginMm: top,
      backgrounds: const [PhotoBackground.white],
      validityMonths: 6,
      rules: rules,
      pro: false,
      verified: true,
    );

// 3000 x 4000 photo, face box 800 x 1000 at (1100, 1400), crown at 1100.
const _a = PhotoAnalysis(
  width: 3000,
  height: 4000,
  faceCount: 1,
  hasMask: true,
  faceLeft: 1100,
  faceTop: 1400,
  faceWidth: 800,
  faceHeight: 1000,
  crownY: 1100,
  yaw: 2,
  roll: 1,
  faceLuma: 150,
);

void main() {
  group('cropFor', () {
    test('keeps the spec aspect ratio and centres the face', () {
      final c = cropFor(_a, _spec())!;
      expect(c.width / c.height, closeTo(30 / 40, 1e-9));
      expect(c.left + c.width / 2, closeTo(1500, 1e-9));
    });

    test('uses the spec head size and top margin when given', () {
      // Passport: head 34 of 45 mm, crown 4 mm from the top.
      final c = cropFor(_a, _spec(h: 45, w: 35, head: 34, top: 4))!;
      const head = 2400 - 1100; // chin (face bottom) - crown
      expect(head / c.height, closeTo(34 / 45, 1e-9));
      expect((1100 - c.top) / c.height, closeTo(4 / 45, 1e-9));
    });

    test('falls back to the default ratios without numbers', () {
      final c = cropFor(_a, _spec())!;
      expect(1300 / c.height, closeTo(defaultHeadRatio, 1e-9));
      expect((1100 - c.top) / c.height, closeTo(defaultTopRatio, 1e-9));
    });

    test('zoom enlarges the head, positive shift moves it down', () {
      final base = cropFor(_a, _spec())!;
      final zoomed = cropFor(_a, _spec(), adjust: const FramingAdjust(zoom: 1.1))!;
      expect(zoomed.height, lessThan(base.height));
      final lower = cropFor(_a, _spec(), adjust: const FramingAdjust(shift: 0.05))!;
      expect(lower.top, lessThan(base.top));
    });

    test('estimates the crown without a mask', () {
      const noMask = PhotoAnalysis(
        width: 3000,
        height: 4000,
        faceCount: 1,
        hasMask: false,
        faceLeft: 1100,
        faceTop: 1400,
        faceWidth: 800,
        faceHeight: 1000,
      );
      expect(crownOf(noMask), closeTo(1050, 1e-9));
      expect(cropFor(noMask, _spec()), isNotNull);
    });

    test('returns null without a face', () {
      const none = PhotoAnalysis(width: 10, height: 10, faceCount: 0, hasMask: false);
      expect(cropFor(none, _spec()), isNull);
    });
  });

  group('reviewPhoto', () {
    test('a good photo passes everything', () {
      final r = reviewPhoto(_a, _spec(), replaceBackground: true);
      expect(r.allPassed, isTrue);
      expect(r.total, ReviewCheck.values.length);
    });

    test('flags two people, a turned head, closed eyes and darkness', () {
      const bad = PhotoAnalysis(
        width: 3000,
        height: 4000,
        faceCount: 2,
        hasMask: true,
        faceLeft: 1100,
        faceTop: 1400,
        faceWidth: 800,
        faceHeight: 1000,
        yaw: 20,
        faceLuma: 40,
      );
      const eyesShut = FaceMetrics(
        faceCount: 1,
        leftEyeOpen: 0.1,
        rightEyeOpen: 0.2,
        brightness: 40,
      );
      final r = reviewPhoto(bad, _spec(), metrics: eyesShut, replaceBackground: true);
      expect(
        r.failed,
        [ReviewCheck.onlyYou, ReviewCheck.straight, ReviewCheck.eyes, ReviewCheck.light],
      );
    });

    test('no mask fails the background only when it would be replaced', () {
      const noMask = PhotoAnalysis(
        width: 3000,
        height: 4000,
        faceCount: 1,
        hasMask: false,
        faceLeft: 1100,
        faceTop: 1400,
        faceWidth: 800,
        faceHeight: 1000,
      );
      expect(
        reviewPhoto(noMask, _spec(), replaceBackground: true).failed,
        [ReviewCheck.background],
      );
      expect(reviewPhoto(noMask, _spec(), replaceBackground: false).allPassed, isTrue);
    });

    test('noEdit documents forbid edits', () {
      expect(forbidsEdits(_spec(rules: const [PhotoRule.noEdit])), isTrue);
      expect(forbidsEdits(_spec()), isFalse);
    });
  });

  group('measured checks', () {
    final residence = _spec(head: 25, tol: 3);

    test('head range comes from the spec, or the default tolerance', () {
      expect(headRangeMm(residence), (22.0, 28.0));
      final (lo, hi) = headRangeMm(_spec());
      expect(hi - lo, closeTo(2 * defaultHeadToleranceMm, 1e-9));
      expect((lo + hi) / 2, closeTo(defaultHeadRatio * 40, 1e-9));
    });

    test('the chin comes from landmarks when present', () {
      const withChin = PhotoAnalysis(
        width: 3000,
        height: 4000,
        faceCount: 1,
        hasMask: true,
        faceLeft: 1100,
        faceTop: 1400,
        faceWidth: 800,
        faceHeight: 1000,
        crownY: 1100,
        chinY: 2450,
      );
      expect(chinOf(withChin), 2450);
      expect(chinOf(_a), 2400);
    });

    RenderResult r({double head = 25, double balance = 0.95, double spread = 3}) => RenderResult(
          path: 'x.jpg',
          headMm: head,
          faceLuma: 160,
          faceBalance: balance,
          backgroundSpread: spread,
          backgroundReplaced: true,
        );

    test('a measured head outside the range fails', () {
      expect(reviewPhoto(_a, residence, render: r(), replaceBackground: true).allPassed, isTrue);
      expect(
        reviewPhoto(_a, residence, render: r(head: 30), replaceBackground: true).failed,
        [ReviewCheck.head],
      );
    });

    test('a one-sided shadow and a busy background fail', () {
      expect(
        reviewPhoto(_a, residence, render: r(balance: 0.6), replaceBackground: true).failed,
        [ReviewCheck.light],
      );
      expect(
        reviewPhoto(_a, residence, render: r(spread: 20), replaceBackground: true).failed,
        [ReviewCheck.background],
      );
    });

    test('edit level follows the document', () {
      expect(editLevelFor(_spec(rules: const [PhotoRule.noEdit])), EditLevel.strict);
      expect(editLevelFor(_spec(id: 'jp_resume')), EditLevel.cv);
      expect(editLevelFor(residence), EditLevel.standard);
      expect(isOfficialDocument(_spec(id: 'jp_resume')), isFalse);
    });
  });
}
