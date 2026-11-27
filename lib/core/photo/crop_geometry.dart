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

/// Head size and top margin used when a spec gives no numbers: a head of
/// about two thirds of the height and a tenth above it, which sits inside
/// every sourced Japanese rule we have (residence 22-28 of 40 mm, passport
/// 32-36 of 45 mm). Replace per spec once a sourced figure is added to
/// `photo_specs.json`.
const double defaultHeadRatio = 0.66;
const double defaultTopRatio = 0.10;

/// Allowed head-size error when a spec gives no tolerance, in mm.
const double defaultHeadToleranceMm = 2;

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

/// The chin: the lowest face-contour landmark when the device found one,
/// else the bottom of the face box.
double chinOf(PhotoAnalysis a) => a.chinY ?? (a.faceTop! + a.faceHeight!);

/// Target head size in mm for [spec].
double headTargetMm(PhotoSpec spec) => headRatioFor(spec) * spec.heightMm;

/// Allowed head-size range in mm for [spec].
(double, double) headRangeMm(PhotoSpec spec) {
  final tol = spec.headToleranceMm ?? defaultHeadToleranceMm;
  final target = headTargetMm(spec);
  return (target - tol, target + tol);
}

/// The crop that puts the head at the spec's size and position.
///
/// Returns null without a face.
CropRect? cropFor(
  PhotoAnalysis a,
  PhotoSpec spec, {
  FramingAdjust adjust = const FramingAdjust(),
}) {
  if (!a.hasFace) return null;
  final crown = crownOf(a);
  final chin = chinOf(a);
  final head = chin - crown;
  if (head <= 0) return null;

  final headRatio = headRatioFor(spec) * adjust.zoom;
  final cropH = head / headRatio;
  final cropW = cropH * spec.widthMm / spec.heightMm;
  final top = crown - (topRatioFor(spec) + adjust.shift) * cropH;
  final centerX = a.faceLeft! + a.faceWidth! / 2;
  return CropRect(_keepInsideX(centerX - cropW / 2, cropW, a.width), top, cropW, cropH);
}

/// Largest sideways nudge, as a share of the crop width, used to keep the
/// crop inside the photo. A crop past the left or right edge makes the
/// renderer repeat the edge pixels, which shows as a streak down the side.
/// A few percent keeps the face visibly centred.
const double maxSideNudge = 0.04;

double _keepInsideX(double left, double cropW, double imageW) {
  if (cropW >= imageW) return left;
  double nudge = 0;
  if (left < 0) {
    nudge = -left;
  } else if (left + cropW > imageW) {
    nudge = imageW - (left + cropW);
  }
  if (nudge.abs() > cropW * maxSideNudge) return left;
  return left + nudge;
}
