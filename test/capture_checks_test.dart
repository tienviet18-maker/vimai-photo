import 'package:flutter_test/flutter_test.dart';
import 'package:vimai_photo/core/capture/capture_checks.dart';
import 'package:vimai_photo/core/capture/face_metrics.dart';
import 'package:vimai_photo/core/capture/voice_coach.dart';

/// A face that passes every check: centred at 42% height, 38% tall.
FaceMetrics good({
  double left = 0.32,
  double top = 0.23,
  double width = 0.36,
  double height = 0.38,
  double yaw = 1,
  double pitch = 2,
  double roll = 1,
  double eyes = 0.95,
  double smile = 0.1,
  double brightness = 140,
  int faces = 1,
}) =>
    FaceMetrics(
      faceCount: faces,
      left: left,
      top: top,
      width: width,
      height: height,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      leftEyeOpen: eyes,
      rightEyeOpen: eyes,
      smiling: smile,
      brightness: brightness,
    );

void main() {
  group('evaluateFrame', () {
    test('a good frame passes every check', () {
      final e = evaluateFrame(good());
      expect(e.allPassed, isTrue);
      expect(e.hints, isEmpty);
    });

    test('no face: only light can pass, first hint is noFace', () {
      final e = evaluateFrame(const FaceMetrics.none(brightness: 140));
      expect(e.passed, {CaptureCheck.light});
      expect(e.primaryHint, CaptureHint.noFace);
    });

    test('dark room without a face asks for light second', () {
      final e = evaluateFrame(const FaceMetrics.none(brightness: 30));
      expect(e.hints, [CaptureHint.noFace, CaptureHint.needLight]);
    });

    test('two faces are rejected', () {
      expect(evaluateFrame(good(faces: 2)).primaryHint, CaptureHint.manyFaces);
    });

    test('small face asks to come closer, large asks to move back', () {
      expect(
        evaluateFrame(good(height: 0.2, top: 0.32)).primaryHint,
        CaptureHint.moveCloser,
      );
      expect(
        evaluateFrame(good(height: 0.6, top: 0.12)).primaryHint,
        CaptureHint.moveBack,
      );
    });

    test('face left of centre on a mirrored preview asks to move right', () {
      final e = evaluateFrame(good(left: 0.1));
      expect(e.passed.contains(CaptureCheck.face), isFalse);
      expect(e.hints, contains(CaptureHint.moveRight));
    });

    test('face too low asks to move up', () {
      expect(evaluateFrame(good(top: 0.45)).hints, contains(CaptureHint.moveUp));
    });

    test('turned head fails straight, tilted head fails level', () {
      final turned = evaluateFrame(good(yaw: 15));
      expect(turned.passed.contains(CaptureCheck.straight), isFalse);
      expect(turned.hints, contains(CaptureHint.lookStraight));

      final tilted = evaluateFrame(good(roll: 9));
      expect(tilted.passed.contains(CaptureCheck.level), isFalse);
      expect(tilted.hints, contains(CaptureHint.levelHead));
    });

    test('closed eyes fail; unknown eye state does not', () {
      expect(evaluateFrame(good(eyes: 0.2)).hints, contains(CaptureHint.openEyes));
      const unknown = FaceMetrics(
        faceCount: 1,
        left: 0.32,
        top: 0.23,
        width: 0.36,
        height: 0.38,
        brightness: 140,
      );
      expect(evaluateFrame(unknown).allPassed, isTrue);
    });

    test('over-exposed frame asks to avoid sunlight', () {
      expect(evaluateFrame(good(brightness: 240)).hints, contains(CaptureHint.tooBright));
    });
  });

  group('StabilityGate', () {
    final t0 = DateTime(2026, 11, 15, 12);
    final pass = evaluateFrame(good());
    final fail = evaluateFrame(good(yaw: 20));

    test('fires only after all checks stay green for the hold time', () {
      final gate = StabilityGate();
      expect(gate.update(pass, t0), isFalse);
      expect(gate.update(pass, t0.add(const Duration(milliseconds: 400))), isFalse);
      expect(gate.progress(t0.add(const Duration(milliseconds: 350))), closeTo(0.5, 0.01));
      expect(gate.update(pass, t0.add(const Duration(milliseconds: 700))), isTrue);
    });

    test('a failing frame restarts the hold', () {
      final gate = StabilityGate();
      gate.update(pass, t0);
      gate.update(fail, t0.add(const Duration(milliseconds: 600)));
      expect(gate.update(pass, t0.add(const Duration(milliseconds: 800))), isFalse);
      expect(gate.progress(t0.add(const Duration(milliseconds: 800))), 0);
    });
  });

  group('pickBest', () {
    test('prefers open eyes and a straight head', () {
      final frames = [
        good(eyes: 0.4),
        good(yaw: 6, roll: 4),
        good(),
      ];
      expect(pickBest(frames), 2);
    });

    test('penalises a big smile', () {
      expect(pickBest([good(smile: 0.9), good(smile: 0.2)]), 1);
    });

    test('ignores frames without exactly one face', () {
      expect(pickBest([good(faces: 0), good(faces: 2)]), isNull);
      expect(pickBest([good(faces: 2), good(eyes: 0.7)]), 1);
    });

    test('stills without a normalised box are not penalised for position', () {
      final still = good(width: 0, left: 0);
      expect(frameScore(still), frameScore(good()));
    });
  });

  group('VoiceCoach', () {
    final t0 = DateTime(2026, 11, 15, 12);

    test('speaks a new hint, then waits before speaking again', () {
      final coach = VoiceCoach();
      expect(coach.next(CaptureHint.moveCloser, t0), CaptureHint.moveCloser);
      expect(coach.next(CaptureHint.lookStraight, t0.add(const Duration(seconds: 1))), isNull);
      expect(
        coach.next(CaptureHint.lookStraight, t0.add(const Duration(seconds: 3))),
        CaptureHint.lookStraight,
      );
    });

    test('repeats the same hint only after twice the gap', () {
      final coach = VoiceCoach();
      coach.next(CaptureHint.openEyes, t0);
      expect(coach.next(CaptureHint.openEyes, t0.add(const Duration(seconds: 3))), isNull);
      expect(
        coach.next(CaptureHint.openEyes, t0.add(const Duration(seconds: 6))),
        CaptureHint.openEyes,
      );
    });
  });
}
