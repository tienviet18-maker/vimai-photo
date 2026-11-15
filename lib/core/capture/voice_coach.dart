import 'capture_checks.dart';

/// Decides when a hint is spoken: only when it changes, never more often
/// than [minGap], so the coach helps instead of chattering.
class VoiceCoach {
  VoiceCoach({this.minGap = const Duration(milliseconds: 2500)});

  final Duration minGap;
  CaptureHint? _last;
  DateTime? _lastAt;

  /// Returns the hint to speak now, or null to stay quiet.
  CaptureHint? next(CaptureHint? hint, DateTime now) {
    if (hint == null) {
      _last = null;
      return null;
    }
    final lastAt = _lastAt;
    final tooSoon = lastAt != null && now.difference(lastAt) < minGap;
    if (tooSoon) return null;
    // Repeat the same hint only after a longer pause.
    if (hint == _last && lastAt != null && now.difference(lastAt) < minGap * 2) {
      return null;
    }
    _last = hint;
    _lastAt = now;
    return hint;
  }

  void reset() {
    _last = null;
    _lastAt = null;
  }
}
