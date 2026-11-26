import 'review_checks.dart';

/// Skin care the user can tune, each 0…1. Nothing here changes the shape of
/// the face; the native side only touches skin inside the face oval.
class BeautySettings {
  const BeautySettings({
    this.smooth = 0,
    this.brighten = 0,
    this.even = 0,
    this.shine = 0,
    this.sharpen = 0,
    this.lips = 0,
  });

  static const none = BeautySettings();

  final double smooth;
  final double brighten;
  final double even;
  final double shine;
  final double sharpen;

  /// A natural rose tint on the lips.
  final double lips;

  bool get isNone => smooth + brighten + even + shine + sharpen + lips < 0.001;

  BeautySettings copyWith({
    double? smooth,
    double? brighten,
    double? even,
    double? shine,
    double? sharpen,
    double? lips,
  }) =>
      BeautySettings(
        smooth: smooth ?? this.smooth,
        brighten: brighten ?? this.brighten,
        even: even ?? this.even,
        shine: shine ?? this.shine,
        sharpen: sharpen ?? this.sharpen,
        lips: lips ?? this.lips,
      );

  Map<String, double> toMap() => {
        'smooth': smooth,
        'brighten': brighten,
        'even': even,
        'shine': shine,
        'sharpen': sharpen,
        'lips': lips,
      };

  @override
  bool operator ==(Object other) =>
      other is BeautySettings &&
      other.smooth == smooth &&
      other.brighten == brighten &&
      other.even == even &&
      other.shine == shine &&
      other.sharpen == sharpen &&
      other.lips == lips;

  @override
  int get hashCode => Object.hash(smooth, brighten, even, shine, sharpen, lips);
}

/// Starting point per document: a natural touch for a CV, a light one for
/// the residence card and My Number, nothing for passports and licences
/// (the user can still turn it on after a warning).
BeautySettings defaultBeautyFor(EditLevel level) => switch (level) {
      EditLevel.cv => const BeautySettings(smooth: 0.35, brighten: 0.25, even: 0.3, shine: 0.4, sharpen: 0.2, lips: 0.2),
      EditLevel.standard => const BeautySettings(smooth: 0.15, brighten: 0.15, even: 0.15, shine: 0.25, sharpen: 0.1),
      EditLevel.strict => BeautySettings.none,
    };
