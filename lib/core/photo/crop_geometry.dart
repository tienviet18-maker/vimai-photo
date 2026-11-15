import '../specs/photo_spec.dart';
import 'photo_analysis.dart';

/// A rectangle in source-image pixels (origin top left). It may reach past
/// the image edges; the renderer fills that area with the background.
class CropRect {
  const CropRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  Map<String, double> toMap() =>
      {'left': left, 'top': top, 'width': width, 'height': height};

  @override
  String toString() => 'CropRect($left, $top, $width, $height)';
}

/// Head size and top margin used when a spec gives no numbers.
///
/// Taken from the Japanese passport rule (head 34 of 45 mm, top margin
/// 4 of 45 mm) scaled to the photo height. Replace per spec once a sourced
/// figure is added to `photo_specs.json`.
const double defaultHeadRatio = 34 / 45;
const double defaultTopRatio = 4 / 45;

/// The user's framing tweaks from the review screen.
class FramingAdjust {
  const FramingAdjust({this.zoom = 1, this.shift = 0});

  /// > 1 makes the head bigger in the photo.
  final double zoom;

  /// Moves the head down (positive) or up, as a share of the photo height.
  final double shift;
}

double headRatioFor(PhotoSpec spec) =>
    spec.headHeightMm != null ? spec.headHeightMm! / spec.heightMm : defaultHeadRatio;

double topRatioFor(PhotoSpec spec) =>
    spec.topMarginMm != null ? spec.topMarginMm! / spec.heightMm : defaultTopRatio;

/// Where the crown is when there is no person mask: hair usually adds about
/// a third of the face box above it.
double crownOf(PhotoAnalysis a) => a.crownY ?? (a.faceTop! - a.faceHeight! * 0.35);

/// The crop that puts the head at the spec's size and position.
///
/// The face box bottom is taken as the chin. Returns null without a face.
CropRect? cropFor(
  PhotoAnalysis a,
  PhotoSpec spec, {
  FramingAdjust adjust = const FramingAdjust(),
}) {
  if (!a.hasFace) return null;
  final crown = crownOf(a);
  final chin = a.faceTop! + a.faceHeight!;
  final head = chin - crown;
  if (head <= 0) return null;

  final headRatio = headRatioFor(spec) * adjust.zoom;
  final cropH = head / headRatio;
  final cropW = cropH * spec.widthMm / spec.heightMm;
  final top = crown - (topRatioFor(spec) + adjust.shift) * cropH;
  final centerX = a.faceLeft! + a.faceWidth! / 2;
  return CropRect(centerX - cropW / 2, top, cropW, cropH);
}
