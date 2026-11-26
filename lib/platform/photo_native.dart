import 'package:flutter/services.dart';

import '../core/photo/crop_geometry.dart';
import '../core/photo/photo_analysis.dart';
import '../core/photo/review_checks.dart';

/// Thrown when the platform has no implementation yet (Android for now).
class PhotoNativeUnavailable implements Exception {
  const PhotoNativeUnavailable();
}

/// Bridge to the on-device image code in `ios/Runner/AppDelegate.swift`.
/// Every call works on local files; nothing is uploaded.
class PhotoNative {
  const PhotoNative();

  static const _channel = MethodChannel('vimai/photo');

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw const PhotoNativeUnavailable();
    }
  }

  Future<PhotoAnalysis> analyze(String path) async {
    final m = await _call<Map<Object?, Object?>>('analyze', {'path': path});
    return PhotoAnalysis.fromMap(m!);
  }

  /// Renders the photo at its exact print size: light and colour corrected,
  /// background replaced when asked, then measured on the result.
  Future<RenderResult> render({
    required String path,
    required PhotoAnalysis analysis,
    required CropRect crop,
    required int outWidth,
    required int outHeight,
    required double heightMm,
    required int backgroundArgb,
    required bool replaceBackground,
    required EditLevel level,
    double exposure = 0,
    bool before = false,
    int dpi = 300,
  }) async {
    final out = await _call<Map<Object?, Object?>>('render', {
      'path': path,
      'crop': crop.toMap(),
      'outWidth': outWidth,
      'outHeight': outHeight,
      'heightMm': heightMm,
      'background': backgroundArgb,
      'replaceBackground': replaceBackground,
      'level': level.name,
      'exposure': exposure,
      'before': before,
      'dpi': dpi,
      if (analysis.hasFace)
        'face': {
          'left': analysis.faceLeft,
          'top': analysis.faceTop,
          'width': analysis.faceWidth,
          'height': analysis.faceHeight,
        },
      if (analysis.hasFace) 'crownY': crownOf(analysis),
      if (analysis.hasFace) 'chinY': chinOf(analysis),
    });
    return RenderResult.fromMap(out!);
  }

  /// Lays copies of [photoPath] on a sheet. Slots are pixel positions.
  Future<String> renderSheet({
    required String photoPath,
    required int sheetWidth,
    required int sheetHeight,
    required int photoWidth,
    required int photoHeight,
    required List<(double, double)> slots,
    required bool cutGuides,
    int dpi = 300,
  }) async {
    final out = await _call<String>('renderSheet', {
      'photoPath': photoPath,
      'sheetWidth': sheetWidth,
      'sheetHeight': sheetHeight,
      'photoWidth': photoWidth,
      'photoHeight': photoHeight,
      'slots': [for (final s in slots) [s.$1, s.$2]],
      'cutGuides': cutGuides,
      'dpi': dpi,
    });
    return out!;
  }

  Future<bool> saveToPhotos(String path) async =>
      await _call<bool>('saveToPhotos', {'path': path}) ?? false;

  Future<void> share(String path) => _call<bool>('share', {'path': path});

  /// Opens the system photo picker. Null when the user cancels.
  Future<String?> pickPhoto() => _call<String>('pickPhoto', {'limit': 1});

  /// Picks several photos (for the test set). Empty when cancelled.
  Future<List<String>> pickPhotos() async {
    final list = await _call<List<Object?>>('pickPhoto', {'limit': 0});
    return [for (final p in list ?? const <Object?>[]) p! as String];
  }

  Future<void> clearCache() => _call<void>('clearCache');

  /// Apple's own rating sheet. iOS decides whether it actually appears
  /// (at most three times a year), so this never blocks or promises anything.
  Future<void> requestReview() => _call<void>('requestReview');

  /// Folder for saved photos (Application Support/photos). Kept by iOS,
  /// unlike the temporary folder render output goes to.
  Future<String> appDir() async => (await _call<String>('appDir'))!;

  /// Local notification at [at]. False when the user declines notifications.
  Future<bool> scheduleReminder({
    required String id,
    required DateTime at,
    required String title,
    required String body,
  }) async =>
      await _call<bool>('scheduleReminder', {
        'id': id,
        'at': at.millisecondsSinceEpoch.toDouble(),
        'title': title,
        'body': body,
      }) ??
      false;

  Future<void> cancelReminder(String id) => _call<void>('cancelReminder', {'id': id});
}
