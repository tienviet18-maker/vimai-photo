import 'package:shared_preferences/shared_preferences.dart';

/// When to ask for an App Store rating.
///
/// Asked right after a photo is saved (the moment the user has what they
/// came for), on the 1st, 3rd and 8th save, and never twice within
/// [minGap]. iOS itself shows the sheet at most three times a year, and
/// Apple forbids asking only happy users or offering anything for stars,
/// so this only picks good moments.
class ReviewPrompt {
  ReviewPrompt(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const askOnSave = {1, 3, 8};
  static const minGap = Duration(days: 60);
  static const _savesKey = 'review.saves';
  static const _lastKey = 'review.lastAsked';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  int get saves => _prefs.getInt(_savesKey) ?? 0;

  /// Records one successful save; true when the rating sheet should be
  /// requested now.
  Future<bool> recordSave() async {
    final count = saves + 1;
    await _prefs.setInt(_savesKey, count);
    if (!askOnSave.contains(count)) return false;
    final now = _clock();
    final last = _prefs.getInt(_lastKey);
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < minGap) {
      return false;
    }
    await _prefs.setInt(_lastKey, now.millisecondsSinceEpoch);
    return true;
  }
}
