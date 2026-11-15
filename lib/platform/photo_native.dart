import 'package:flutter/services.dart';

import '../core/photo/crop_geometry.dart';
import '../core/photo/photo_analysis.dart';

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

  /// Renders the photo at its exact print size and returns a JPEG path.
  Future<String> render({
    required String path,
    required CropRect crop,
    required int outWidth,
    required int outHeight,
    required int backgroundArgb,
    required bool replaceBackground,
    double exposure = 0,
    int dpi = 300,
  }) async {
    final out = await _call<String>('render', {
      'path': path,
      'crop': crop.toMap(),
      'outWidth': outWidth,
      'outHeight': outHeight,
      'background': backgroundArgb,
      'replaceBackground': replaceBackground,
      'exposure': exposure,
      'dpi': dpi,
    });
    return out!;
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
  Future<String?> pickPhoto() => _call<String>('pickPhoto');

  Future<void> clearCache() => _call<void>('clearCache');
}
