import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/capture/face_metrics.dart';

/// Turns camera frames and still photos into [FaceMetrics] with ML Kit.
/// Everything runs on the device; no image leaves the phone.
class FaceAnalyzer {
  FaceAnalyzer()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableClassification: true,
            minFaceSize: 0.15,
          ),
        );

  final FaceDetector _detector;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Returns null when the frame format is not supported on this platform.
  Future<FaceMetrics?> analyzeFrame(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    final rotation = _rotation(camera, deviceOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    final supported = Platform.isAndroid
        ? format == InputImageFormat.nv21
        : format == InputImageFormat.bgra8888;
    if (format == null || !supported || image.planes.length != 1) return null;

    final plane = image.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );

    final faces = await _detector.processImage(input);
    final sideways = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final uprightW = (sideways ? image.height : image.width).toDouble();
    final uprightH = (sideways ? image.width : image.height).toDouble();

    return _toMetrics(
      faces,
      brightness: _brightness(plane.bytes, image.width, image.height,
          bytesPerRow: plane.bytesPerRow, bgra: format == InputImageFormat.bgra8888),
      frameW: uprightW,
      frameH: uprightH,
      mirror: camera.lensDirection == CameraLensDirection.front,
    );
  }

  /// Angles and eye state for a still photo. The box is not normalised.
  Future<FaceMetrics> analyzeFile(String path) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    return _toMetrics(faces, brightness: 128, frameW: 0, frameH: 0, mirror: false);
  }

  Future<void> close() => _detector.close();

  InputImageRotation? _rotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS) return InputImageRotationValue.fromRawValue(sensor);
    var compensation = _orientations[deviceOrientation];
    if (compensation == null) return null;
    compensation = camera.lensDirection == CameraLensDirection.front
        ? (sensor + compensation) % 360
        : (sensor - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensation);
  }

  FaceMetrics _toMetrics(
    List<Face> faces, {
    required double brightness,
    required double frameW,
    required double frameH,
    required bool mirror,
  }) {
    if (faces.isEmpty) return FaceMetrics.none(brightness: brightness);
    final f = faces.first;
    final box = f.boundingBox;
    final normalise = frameW > 0 && frameH > 0;
    var left = normalise ? box.left / frameW : 0.0;
    final width = normalise ? box.width / frameW : 0.0;
    if (mirror && normalise) left = 1 - left - width;
    return FaceMetrics(
      faceCount: faces.length,
      left: left,
      top: normalise ? box.top / frameH : 0,
      width: width,
      height: normalise ? box.height / frameH : 0,
      yaw: f.headEulerAngleY,
      pitch: f.headEulerAngleX,
      roll: f.headEulerAngleZ,
      leftEyeOpen: f.leftEyeOpenProbability,
      rightEyeOpen: f.rightEyeOpenProbability,
      smiling: f.smilingProbability,
      brightness: brightness,
    );
  }

  /// Mean luma from a sparse grid of samples (cheap enough per frame).
  static double _brightness(
    Uint8List bytes,
    int width,
    int height, {
    required int bytesPerRow,
    required bool bgra,
  }) {
    const step = 16;
    var sum = 0.0;
    var n = 0;
    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        if (bgra) {
          final i = y * bytesPerRow + x * 4;
          if (i + 2 >= bytes.length) continue;
          sum += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
        } else {
          // NV21: the first width*height bytes are the Y (luma) plane.
          final i = y * bytesPerRow + x;
          if (i >= bytes.length) continue;
          sum += bytes[i];
        }
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }
}
