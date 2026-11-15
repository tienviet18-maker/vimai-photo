import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_spec.dart';

class SpecRepository {
  SpecRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/specs/photo_specs.json';

  final AssetBundle _bundle;

  /// Loads all specs. In release builds unverified specs are dropped so a
  /// standard nobody has checked never reaches users.
  Future<List<PhotoSpec>> load({bool includeUnverified = !kReleaseMode}) async {
    final raw = await _bundle.loadString(assetPath);
    return parse(raw, includeUnverified: includeUnverified);
  }

  static List<PhotoSpec> parse(String raw, {required bool includeUnverified}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final specs = (json['specs'] as List<dynamic>)
        .map((e) => PhotoSpec.fromJson(e as Map<String, dynamic>))
        .where((s) => includeUnverified || s.verified)
        .toList(growable: false);
    final ids = specs.map((s) => s.id).toSet();
    if (ids.length != specs.length) {
      throw const FormatException('Duplicate spec id in photo_specs.json');
    }
    return specs;
  }
}
