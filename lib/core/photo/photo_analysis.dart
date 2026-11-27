/// What the device found in one still photo, in pixels of the upright image
/// (origin top left). Built from the native `analyze` call.
class PhotoAnalysis {
  const PhotoAnalysis({
    required this.width,
    required this.height,
    required this.faceCount,
    required this.hasMask,
    this.faceLeft,
    this.faceTop,
    this.faceWidth,
    this.faceHeight,
    this.crownY,
    this.yaw,
    this.roll,
    this.pitch,
    this.faceLuma,
  });

  factory PhotoAnalysis.fromMap(Map<Object?, Object?> m) {
    double? d(Object? v) => (v as num?)?.toDouble();
    final face = m['face'] as Map<Object?, Object?>?;
    return PhotoAnalysis(
      width: d(m['width'])!,
      height: d(m['height'])!,
      faceCount: (m['faceCount'] as num?)?.toInt() ?? 0,
      hasMask: m['hasMask'] as bool? ?? false,
      faceLeft: d(face?['left']),
      faceTop: d(face?['top']),
      faceWidth: d(face?['width']),
      faceHeight: d(face?['height']),
      crownY: d(m['crownY']),
      yaw: d(m['yaw']),
      roll: d(m['roll']),
      pitch: d(m['pitch']),
      faceLuma: d(m['faceLuma']),
    );
  }

  final double width;
  final double height;
  final int faceCount;

  /// True when a person mask was found, so the background can be replaced.
  final bool hasMask;

  final double? faceLeft;
  final double? faceTop;
  final double? faceWidth;
  final double? faceHeight;

  /// Top of the hair, from the person mask. Null without a mask.
  final double? crownY;

  /// Head angles in degrees.
  final double? yaw;
  final double? roll;
  final double? pitch;

  /// Mean luma 0..255 inside the face box.
  final double? faceLuma;

  bool get hasFace =>
      faceLeft != null && faceTop != null && faceWidth != null && faceHeight != null;
}
