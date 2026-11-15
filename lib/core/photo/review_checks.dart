import '../capture/face_metrics.dart';
import '../specs/photo_spec.dart';
import 'crop_geometry.dart';
import 'photo_analysis.dart';

/// The checklist on the review screen.
enum ReviewCheck { size, head, background, onlyYou, straight, eyes, light }

/// How much the app may change a photo, decided by the document.
enum EditLevel {
  /// Passport, driving licence: crop and whole-photo light and colour only.
  /// The background is replaced only when the user accepts the warning.
  strict,

  /// Residence card, My Number: also a plain background and softening a
  /// shadow on one side of the face. Never the face itself.
  standard,

  /// CV photo: also light skin smoothing and less shine.
  cv,
}

EditLevel editLevelFor(PhotoSpec spec) {
  if (spec.rules.contains(PhotoRule.noEdit)) return EditLevel.strict;
  if (spec.id == 'jp_resume') return EditLevel.cv;
  return EditLevel.standard;
}

/// Documents where any image processing may be refused.
bool forbidsEdits(PhotoSpec spec) => editLevelFor(spec) == EditLevel.strict;

/// Documents handed to an authority (everything except a CV photo).
bool isOfficialDocument(PhotoSpec spec) => editLevelFor(spec) != EditLevel.cv;

/// What the device measured on the finished photo.
class RenderResult {
  const RenderResult({
    required this.path,
    this.headMm,
    this.topMarginMm,
    this.faceLuma,
    this.faceBalance,
    this.backgroundSpread,
    this.backgroundReplaced = false,
  });

  factory RenderResult.fromMap(Map<Object?, Object?> m) {
    double? d(Object? v) => (v as num?)?.toDouble();
    return RenderResult(
      path: m['path']! as String,
      headMm: d(m['headMm']),
      topMarginMm: d(m['topMarginMm']),
      faceLuma: d(m['faceLuma']),
      faceBalance: d(m['faceBalance']),
      backgroundSpread: d(m['backgroundSpread']),
      backgroundReplaced: m['backgroundReplaced'] as bool? ?? false,
    );
  }

  final String path;

  /// Crown (with hair) to chin on the printed photo.
  final double? headMm;

  /// Space above the crown on the printed photo.
  final double? topMarginMm;

  /// Mean luma 0..255 of the face on the finished photo.
  final double? faceLuma;

  /// Darker half of the face over the brighter half, 0..1 (1 = even).
  final double? faceBalance;

  /// Standard deviation of luma over the background, 0..255.
  final double? backgroundSpread;
  final bool backgroundReplaced;
}

class ReviewLimits {
  const ReviewLimits({
    this.maxYaw = 10,
    this.maxRoll = 6,
    this.minEyeOpen = 0.5,
    this.minLuma = 85,
    this.maxLuma = 230,
    this.minFaceBalance = 0.75,
    this.maxBackgroundSpread = 12,
  });

  final double maxYaw;
  final double maxRoll;
  final double minEyeOpen;
  final double minLuma;
  final double maxLuma;
  final double minFaceBalance;
  final double maxBackgroundSpread;
}

class ReviewResult {
  const ReviewResult(this.items);

  /// Every check in display order, with whether it passed.
  final Map<ReviewCheck, bool> items;

  int get passed => items.values.where((ok) => ok).length;
  int get total => items.length;
  bool get allPassed => passed == total;
  List<ReviewCheck> get failed =>
      [for (final e in items.entries) if (!e.value) e.key];
}

/// Checks a still photo. [metrics] (ML Kit, for eyes) is optional: a photo
/// picked from the library has it, but it may report no face.
///
/// With [render] the head size, light and background are judged on the
/// finished photo as measured by the device; without it, on the analysis.
ReviewResult reviewPhoto(
  PhotoAnalysis a,
  PhotoSpec spec, {
  FaceMetrics? metrics,
  RenderResult? render,
  required bool replaceBackground,
  ReviewLimits limits = const ReviewLimits(),
}) {
  final yaw = a.yaw ?? metrics?.yaw;
  final roll = a.roll ?? metrics?.roll;
  final eyes = [metrics?.leftEyeOpen, metrics?.rightEyeOpen].whereType<double>();
  final luma = render?.faceLuma ?? a.faceLuma;
  final balance = render?.faceBalance;

  bool headOk() {
    final mm = render?.headMm;
    if (mm == null) return a.hasFace;
    final (lo, hi) = headRangeMm(spec);
    return mm >= lo && mm <= hi;
  }

  bool backgroundOk() {
    if (replaceBackground && !a.hasMask) return false;
    final spread = render?.backgroundSpread;
    return spread == null || spread <= limits.maxBackgroundSpread;
  }

  final items = <ReviewCheck, bool>{
    // The renderer outputs the exact pixel size at 300 dpi.
    ReviewCheck.size: a.hasFace,
    ReviewCheck.head: headOk(),
    ReviewCheck.background: backgroundOk(),
    ReviewCheck.onlyYou: a.faceCount == 1,
    ReviewCheck.straight: (yaw == null || yaw.abs() <= limits.maxYaw) &&
        (roll == null || roll.abs() <= limits.maxRoll),
    ReviewCheck.eyes: eyes.every((p) => p >= limits.minEyeOpen),
    ReviewCheck.light:
        (luma == null || (luma >= limits.minLuma && luma <= limits.maxLuma)) &&
            (balance == null || balance >= limits.minFaceBalance),
  };
  if (!spec.rules.contains(PhotoRule.onlyYou)) {
    items[ReviewCheck.onlyYou] = a.faceCount >= 1;
  }
  return ReviewResult(items);
}
