import '../capture/face_metrics.dart';
import '../specs/photo_spec.dart';
import 'photo_analysis.dart';

/// The checklist on the review screen.
enum ReviewCheck { size, head, background, onlyYou, straight, eyes, light }

class ReviewLimits {
  const ReviewLimits({
    this.maxYaw = 10,
    this.maxRoll = 6,
    this.minEyeOpen = 0.5,
    this.minLuma = 85,
    this.maxLuma = 230,
  });

  final double maxYaw;
  final double maxRoll;
  final double minEyeOpen;
  final double minLuma;
  final double maxLuma;
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
/// [replaceBackground] is false for documents that forbid edits; then the
/// background check cannot be proven and is left to the user.
ReviewResult reviewPhoto(
  PhotoAnalysis a,
  PhotoSpec spec, {
  FaceMetrics? metrics,
  required bool replaceBackground,
  ReviewLimits limits = const ReviewLimits(),
}) {
  final yaw = a.yaw ?? metrics?.yaw;
  final roll = a.roll ?? metrics?.roll;
  final eyes = [metrics?.leftEyeOpen, metrics?.rightEyeOpen].whereType<double>();
  final luma = a.faceLuma;

  final items = <ReviewCheck, bool>{
    // The renderer outputs the exact pixel size at 300 dpi.
    ReviewCheck.size: a.hasFace,
    // The crop is computed from the head, so it fits whenever a head is found.
    ReviewCheck.head: a.hasFace,
    ReviewCheck.background: replaceBackground ? a.hasMask : true,
    ReviewCheck.onlyYou: a.faceCount == 1,
    ReviewCheck.straight: (yaw == null || yaw.abs() <= limits.maxYaw) &&
        (roll == null || roll.abs() <= limits.maxRoll),
    ReviewCheck.eyes: eyes.every((p) => p >= limits.minEyeOpen),
    ReviewCheck.light:
        luma == null || (luma >= limits.minLuma && luma <= limits.maxLuma),
  };
  if (!spec.rules.contains(PhotoRule.onlyYou)) {
    items[ReviewCheck.onlyYou] = a.faceCount >= 1;
  }
  return ReviewResult(items);
}

/// Official documents where retouching, background replacement and AI
/// outfits are switched off.
bool forbidsEdits(PhotoSpec spec) => spec.rules.contains(PhotoRule.noEdit);

/// Documents handed to an authority (everything except a CV photo). AI
/// outfits and beauty filters stay off for these.
bool isOfficialDocument(PhotoSpec spec) => spec.id != 'jp_resume';
