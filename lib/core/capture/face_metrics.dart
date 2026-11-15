/// What the camera sees in one frame, independent of the detector library,
/// so the checks below can be unit tested without a camera.
///
/// Box coordinates are normalised to 0..1 of the upright frame, as the user
/// sees it on screen (already mirrored for the front camera).
class FaceMetrics {
  const FaceMetrics({
    required this.faceCount,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.yaw,
    this.pitch,
    this.roll,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.smiling,
    required this.brightness,
  });

  /// No face in the frame.
  const FaceMetrics.none({required this.brightness})
      : faceCount = 0,
        left = 0,
        top = 0,
        width = 0,
        height = 0,
        yaw = null,
        pitch = null,
        roll = null,
        leftEyeOpen = null,
        rightEyeOpen = null,
        smiling = null;

  final int faceCount;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Head angles in degrees. Null when the detector gives none.
  final double? yaw;
  final double? pitch;
  final double? roll;

  /// Probabilities 0..1.
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double? smiling;

  /// Mean luma 0..255 over the frame.
  final double brightness;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}
