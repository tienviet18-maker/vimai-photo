/// A photo standard for one document (e.g. residence card, passport).
///
/// All lengths are millimetres. Specs are loaded from
/// `assets/specs/photo_specs.json` so a rule change only needs a data edit.
class PhotoSpec {
  const PhotoSpec({
    required this.id,
    required this.names,
    required this.jaName,
    required this.icon,
    required this.heightMm,
    required this.widthMm,
    required this.backgrounds,
    required this.validityMonths,
    required this.rules,
    required this.pro,
    required this.verified,
    this.headHeightMm,
    this.headToleranceMm,
    this.topMarginMm,
    this.topMarginToleranceMm,
    this.sourceUrl,
    this.notes,
  });

  factory PhotoSpec.fromJson(Map<String, dynamic> json) {
    final names = (json['names'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    return PhotoSpec(
      id: json['id'] as String,
      names: names,
      jaName: json['jaName'] as String,
      icon: json['icon'] as String,
      heightMm: (json['heightMm'] as num).toDouble(),
      widthMm: (json['widthMm'] as num).toDouble(),
      headHeightMm: (json['headHeightMm'] as num?)?.toDouble(),
      headToleranceMm: (json['headToleranceMm'] as num?)?.toDouble(),
      topMarginMm: (json['topMarginMm'] as num?)?.toDouble(),
      topMarginToleranceMm: (json['topMarginToleranceMm'] as num?)?.toDouble(),
      backgrounds: (json['backgrounds'] as List<dynamic>)
          .map((e) => PhotoBackground.fromId(e as String))
          .toList(growable: false),
      validityMonths: json['validityMonths'] as int,
      rules: (json['rules'] as List<dynamic>)
          .map((e) => PhotoRule.fromId(e as String))
          .toList(growable: false),
      pro: json['pro'] as bool,
      verified: json['verified'] as bool,
      sourceUrl: json['sourceUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;

  /// Display names keyed by language code (`en`, `vi`, `ja`).
  final Map<String, String> names;

  /// Original Japanese name, shown next to translations so users can
  /// match it with the real form.
  final String jaName;

  /// Material icon name.
  final String icon;
  final double heightMm;
  final double widthMm;

  /// Crown (including hair) to chin. Null when the source gives none.
  final double? headHeightMm;
  final double? headToleranceMm;

  /// Space between the photo's top edge and the crown.
  final double? topMarginMm;
  final double? topMarginToleranceMm;

  final List<PhotoBackground> backgrounds;
  final int validityMonths;
  final List<PhotoRule> rules;
  final bool pro;

  /// False until the numbers have been checked against [sourceUrl].
  /// Unverified specs are hidden in release builds.
  final bool verified;
  final String? sourceUrl;
  final String? notes;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? jaName;

  /// Pixel size at [dpi] (300 for convenience-store prints).
  ({int width, int height}) pixelSize({int dpi = 300}) => (
        width: mmToPx(widthMm, dpi: dpi),
        height: mmToPx(heightMm, dpi: dpi),
      );
}

const double _mmPerInch = 25.4;

int mmToPx(double mm, {int dpi = 300}) => (mm / _mmPerInch * dpi).round();

enum PhotoBackground {
  white('white'),
  lightBlue('lightBlue'),
  plain('plain');

  const PhotoBackground(this.id);
  final String id;

  static PhotoBackground fromId(String id) => values.firstWhere(
        (b) => b.id == id,
        orElse: () => throw FormatException('Unknown background: $id'),
      );
}

enum PhotoRule {
  onlyYou('onlyYou'),
  noHat('noHat'),
  frontFacing('frontFacing'),
  noShadow('noShadow'),
  upperBody('upperBody'),
  noEdit('noEdit'),
  nameOnBack('nameOnBack'),
  eyesVisible('eyesVisible');

  const PhotoRule(this.id);
  final String id;

  static PhotoRule fromId(String id) => values.firstWhere(
        (r) => r.id == id,
        orElse: () => throw FormatException('Unknown rule: $id'),
      );
}
