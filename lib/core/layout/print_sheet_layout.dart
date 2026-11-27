import 'dart:math' as math;

import '../specs/photo_spec.dart';

/// A print sheet such as the L size (89 × 127 mm) sold at convenience stores.
class SheetSize {
  const SheetSize(this.widthMm, this.heightMm);

  static const lSize = SheetSize(89, 127);
  static const twoL = SheetSize(127, 178);

  final double widthMm;
  final double heightMm;

  ({int width, int height}) pixelSize({int dpi = 300}) => (
        width: mmToPx(widthMm, dpi: dpi),
        height: mmToPx(heightMm, dpi: dpi),
      );
}

/// Where one photo sits on the sheet, in millimetres from the top-left.
class PhotoSlot {
  const PhotoSlot(this.leftMm, this.topMm);
  final double leftMm;
  final double topMm;
}

/// Grid of identical photos centred on a sheet, with a gap between photos
/// (for cutting) and a margin kept clear because printers crop the edge.
class PrintSheetLayout {
  PrintSheetLayout._(
    this.columns,
    this.rows,
    this.slots, {
    required this.sheet,
    required this.landscape,
  });

  /// Tries the sheet upright and turned sideways and keeps whichever fits
  /// more photos (e.g. 40×30 fits 4 upright but 6 sideways on L size).
  factory PrintSheetLayout.grid({
    required PhotoSpec spec,
    SheetSize sheet = SheetSize.lSize,
    double gapMm = 2,
    double marginMm = 3,
  }) {
    final upright = PrintSheetLayout._fixed(spec, sheet, gapMm, marginMm);
    final sideways = PrintSheetLayout._fixed(
      spec,
      SheetSize(sheet.heightMm, sheet.widthMm),
      gapMm,
      marginMm,
      landscape: true,
    );
    return sideways.count > upright.count ? sideways : upright;
  }

  factory PrintSheetLayout._fixed(
    PhotoSpec spec,
    SheetSize sheet,
    double gapMm,
    double marginMm, {
    bool landscape = false,
  }) {
    final usableW = sheet.widthMm - 2 * marginMm;
    final usableH = sheet.heightMm - 2 * marginMm;
    final columns = _fit(usableW, spec.widthMm, gapMm);
    final rows = _fit(usableH, spec.heightMm, gapMm);

    final gridW = columns * spec.widthMm + math.max(0, columns - 1) * gapMm;
    final gridH = rows * spec.heightMm + math.max(0, rows - 1) * gapMm;
    final originX = (sheet.widthMm - gridW) / 2;
    final originY = (sheet.heightMm - gridH) / 2;

    final slots = <PhotoSlot>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < columns; c++)
          PhotoSlot(
            originX + c * (spec.widthMm + gapMm),
            originY + r * (spec.heightMm + gapMm),
          ),
    ];
    return PrintSheetLayout._(
      columns,
      rows,
      List.unmodifiable(slots),
      sheet: sheet,
      landscape: landscape,
    );
  }

  final int columns;
  final int rows;
  final List<PhotoSlot> slots;

  /// The sheet as laid out (width/height swapped when [landscape]).
  final SheetSize sheet;
  final bool landscape;

  int get count => slots.length;

  static int _fit(double available, double item, double gap) {
    if (item > available) return 0;
    return ((available + gap) / (item + gap)).floor();
  }
}
