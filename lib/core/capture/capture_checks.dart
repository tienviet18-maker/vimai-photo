import 'face_metrics.dart';

/// The live checks shown as lights on the camera screen.
enum CaptureCheck { face, distance, straight, level, eyes, light }

/// What the user should do to turn a check green. Order matters: the first
/// failing hint is the one spoken aloud.
enum CaptureHint {
  noFace,
  manyFaces,
  moveCloser,
  moveBack,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  lookStraight,
  levelHead,
  openEyes,
  needLight,
  tooBright,
  holdStill,
}

/// Tunable limits. Kept generous: the final crop fixes small offsets, these
/// only make sure the frame holds a usable, front-facing head.
class CaptureThresholds {
  const CaptureThresholds({
    this.minFaceHeight = 0.28,
    this.maxFaceHeight = 0.50,
    this.maxCenterOffsetX = 0.10,
    this.targetCenterY = 0.42,
    this.maxCenterOffsetY = 0.12,
    this.maxYaw = 8,
    this.maxPitch = 10,
    this.maxRoll = 5,
    this.minEyeOpen = 0.6,
    this.minBrightness = 70,
    this.maxBrightness = 215,
  });

  /// Face box height as a share of the frame height.
  final double minFaceHeight;
  final double maxFaceHeight;
  final double maxCenterOffsetX;
  final double targetCenterY;
  final double maxCenterOffsetY;
  final double maxYaw;
  final double maxPitch;
  final double maxRoll;
  final double minEyeOpen;
  final double minBrightness;
  final double maxBrightness;
}

class CaptureEvaluation {
  const CaptureEvaluation(this.passed, this.hints);

  /// Checks currently green.
  final Set<CaptureCheck> passed;

  /// What to fix, most important first. Empty when everything passes.
  final List<CaptureHint> hints;

  bool get allPassed => passed.length == CaptureCheck.values.length;
  CaptureHint? get primaryHint => hints.isEmpty ? null : hints.first;
}

CaptureEvaluation evaluateFrame(
  FaceMetrics m, {
  CaptureThresholds t = const CaptureThresholds(),
}) {
  final passed = <CaptureCheck>{};
  final hints = <CaptureHint>[];

  // Light is judged even without a face: darkness is often why none is found.
  if (m.brightness < t.minBrightness) {
    hints.add(CaptureHint.needLight);
  } else if (m.brightness > t.maxBrightness) {
    hints.add(CaptureHint.tooBright);
  } else {
    passed.add(CaptureCheck.light);
  }

  if (m.faceCount == 0) {
    hints.insert(0, CaptureHint.noFace);
    return CaptureEvaluation(passed, hints);
  }
  if (m.faceCount > 1) {
    hints.insert(0, CaptureHint.manyFaces);
    return CaptureEvaluation(passed, hints);
  }

  // Face present and centred.
  final dx = m.centerX - 0.5;
  final dy = m.centerY - t.targetCenterY;
  final faceHints = <CaptureHint>[
    if (dx < -t.maxCenterOffsetX) CaptureHint.moveRight,
    if (dx > t.maxCenterOffsetX) CaptureHint.moveLeft,
    if (dy < -t.maxCenterOffsetY) CaptureHint.moveDown,
    if (dy > t.maxCenterOffsetY) CaptureHint.moveUp,
  ];
  if (faceHints.isEmpty) passed.add(CaptureCheck.face);

  if (m.height < t.minFaceHeight) {
    faceHints.insert(0, CaptureHint.moveCloser);
  } else if (m.height > t.maxFaceHeight) {
    faceHints.insert(0, CaptureHint.moveBack);
  } else {
    passed.add(CaptureCheck.distance);
  }
  hints.insertAll(0, faceHints);

  final yawOk = (m.yaw ?? 0).abs() <= t.maxYaw;
  final pitchOk = (m.pitch ?? 0).abs() <= t.maxPitch;
  if (yawOk && pitchOk) {
    passed.add(CaptureCheck.straight);
  } else {
    hints.add(CaptureHint.lookStraight);
  }

  if ((m.roll ?? 0).abs() <= t.maxRoll) {
    passed.add(CaptureCheck.level);
  } else {
    hints.add(CaptureHint.levelHead);
  }

  // Unknown eye state is not held against the user.
  final eyesOk = (m.leftEyeOpen ?? 1) >= t.minEyeOpen &&
      (m.rightEyeOpen ?? 1) >= t.minEyeOpen;
  if (eyesOk) {
    passed.add(CaptureCheck.eyes);
  } else {
    hints.add(CaptureHint.openEyes);
  }

  return CaptureEvaluation(passed, hints);
}

/// Fires once all checks have stayed green for [hold], so a passing glance
/// does not trigger the shutter.
class StabilityGate {
  StabilityGate({this.hold = const Duration(milliseconds: 700)});

  final Duration hold;
  DateTime? _since;

  /// Returns true when the shutter should fire.
  bool update(CaptureEvaluation e, DateTime now) {
    if (!e.allPassed) {
      _since = null;
      return false;
    }
    _since ??= now;
    return now.difference(_since!) >= hold;
  }

  /// 0..1 progress toward [hold], for the ring around the shutter.
  double progress(DateTime now) {
    final since = _since;
    if (since == null) return 0;
    final p = now.difference(since).inMicroseconds / hold.inMicroseconds;
    return p.clamp(0, 1).toDouble();
  }

  void reset() => _since = null;
}

/// Higher is better. Used to keep the best shot of a burst: straight head,
/// open eyes and a neutral expression (official photos reject big smiles).
double frameScore(FaceMetrics m) {
  if (m.faceCount != 1) return double.negativeInfinity;
  final angle = (m.yaw ?? 0).abs() / 8 +
      (m.pitch ?? 0).abs() / 10 +
      (m.roll ?? 0).abs() / 5;
  final eyes = ((m.leftEyeOpen ?? 1) + (m.rightEyeOpen ?? 1)) / 2;
  final smile = m.smiling ?? 0;
  // Stills from a burst may come without a normalised box (width 0).
  final centre = m.width > 0 ? (m.centerX - 0.5).abs() * 4 : 0;
  return eyes * 3 - angle - centre - (smile > 0.5 ? smile : 0);
}

/// Index of the best frame, or null when none has exactly one face.
int? pickBest(List<FaceMetrics> frames) {
  int? best;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i < frames.length; i++) {
    final s = frameScore(frames[i]);
    if (s > bestScore) {
      best = i;
      bestScore = s;
    }
  }
  return best;
}
