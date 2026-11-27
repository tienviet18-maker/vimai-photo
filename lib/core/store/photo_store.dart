import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished photo kept on this iPhone ("My photos").
///
/// Files are stored by name only: the app container path changes between
/// installs and updates, so the folder is resolved again at runtime.
class SavedPhoto {
  const SavedPhoto({
    required this.id,
    required this.specId,
    required this.photoFile,
    required this.takenAt,
    this.sourceFile,
    this.remind = false,
    this.beauty = false,
  });

  factory SavedPhoto.fromJson(Map<String, dynamic> j) => SavedPhoto(
        id: j['id'] as String,
        specId: j['specId'] as String,
        photoFile: j['photo'] as String,
        sourceFile: j['source'] as String?,
        takenAt: DateTime.parse(j['takenAt'] as String),
        remind: j['remind'] as bool? ?? false,
        beauty: j['beauty'] as bool? ?? false,
      );

  final String id;
  final String specId;

  /// The finished photo at its exact print size.
  final String photoFile;

  /// The original shot, so the photo can be made again for another document.
  final String? sourceFile;
  final DateTime takenAt;

  /// A reminder is scheduled before the photo gets too old.
  final bool remind;

  /// Skin care was applied (reprinting it needs the unlock).
  final bool beauty;

  SavedPhoto copyWith({bool? remind}) => SavedPhoto(
        id: id,
        specId: specId,
        photoFile: photoFile,
        sourceFile: sourceFile,
        takenAt: takenAt,
        remind: remind ?? this.remind,
        beauty: beauty,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'specId': specId,
        'photo': photoFile,
        if (sourceFile != null) 'source': sourceFile,
        'takenAt': takenAt.toIso8601String(),
        'remind': remind,
        'beauty': beauty,
      };
}

/// Offices want photos taken within N months. The last day the photo still
/// counts, keeping the day of month where the month allows it.
DateTime expiryOf(DateTime takenAt, int months) {
  final target = DateTime(takenAt.year, takenAt.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final day = takenAt.day < lastDay ? takenAt.day : lastDay;
  return DateTime(target.year, target.month, day);
}

enum ExpiryStatus { valid, soon, expired }

/// "Soon" is the last [soonDays] days, when it is worth taking a new photo.
ExpiryStatus expiryStatus(DateTime expiry, DateTime now, {int soonDays = 30}) {
  final today = DateTime(now.year, now.month, now.day);
  if (today.isAfter(expiry)) return ExpiryStatus.expired;
  if (expiry.difference(today).inDays <= soonDays) return ExpiryStatus.soon;
  return ExpiryStatus.valid;
}

/// Whole months left until [expiry], at least 0.
int monthsLeft(DateTime expiry, DateTime now) {
  var months = (expiry.year - now.year) * 12 + expiry.month - now.month;
  if (expiry.day < now.day) months--;
  return months < 0 ? 0 : months;
}

class PhotoStore extends ChangeNotifier {
  PhotoStore(this._prefs, {required Future<String> Function() directory})
      : _directory = directory,
        _items = _read(_prefs);

  static const _key = 'photos';

  final SharedPreferences _prefs;
  final Future<String> Function() _directory;
  final List<SavedPhoto> _items;
  String? _dir;

  /// Newest first.
  List<SavedPhoto> get items => List.unmodifiable(_items);

  static List<SavedPhoto> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list) SavedPhoto.fromJson(e as Map<String, dynamic>),
      ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    } catch (_) {
      // A damaged list must not stop the app from opening.
      return [];
    }
  }

  Future<String> _folder() async => _dir ??= await _directory();

  /// The folder files live in, for showing thumbnails.
  Future<String> folder() => _folder();

  Future<String> pathOf(String file) async => '${await _folder()}/$file';

  Future<void> _write() =>
      _prefs.setString(_key, jsonEncode([for (final p in _items) p.toJson()]));

  /// Copies the finished photo (and the original shot when given) into the
  /// app's folder and lists it under My photos.
  Future<SavedPhoto> add({
    required String specId,
    required String photoPath,
    String? sourcePath,
    DateTime? takenAt,
    bool beauty = false,
  }) async {
    final dir = await _folder();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final photoFile = 'photo-$id.jpg';
    await File(photoPath).copy('$dir/$photoFile');
    String? sourceFile;
    if (sourcePath != null && File(sourcePath).existsSync()) {
      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
      sourceFile = 'source-$id.$ext';
      await File(sourcePath).copy('$dir/$sourceFile');
    }
    final saved = SavedPhoto(
      id: id,
      specId: specId,
      photoFile: photoFile,
      sourceFile: sourceFile,
      takenAt: takenAt ?? DateTime.now(),
      beauty: beauty,
    );
    _items.insert(0, saved);
    await _write();
    notifyListeners();
    return saved;
  }

  Future<void> update(SavedPhoto photo) async {
    final i = _items.indexWhere((p) => p.id == photo.id);
    if (i < 0) return;
    _items[i] = photo;
    await _write();
    notifyListeners();
  }

  Future<void> remove(SavedPhoto photo) async {
    _items.removeWhere((p) => p.id == photo.id);
    await _write();
    notifyListeners();
    final dir = await _folder();
    for (final f in [photo.photoFile, photo.sourceFile]) {
      if (f == null) continue;
      final file = File('$dir/$f');
      if (file.existsSync()) await file.delete();
    }
  }
}

/// Makes the store reachable from any screen in the flow.
class PhotoStoreScope extends InheritedNotifier<PhotoStore> {
  const PhotoStoreScope({super.key, required PhotoStore store, required super.child})
      : super(notifier: store);

  static PhotoStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoStoreScope>()?.notifier;
}
