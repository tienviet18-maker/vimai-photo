import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of tapping "Unlock".
enum PurchaseOutcome { purchased, cancelled, pending, failed, network, unavailable }

/// What happens when the user wants to save.
enum SaveDecision {
  /// Unlocked, or the free save is still there.
  allowed,

  /// The free save is used up.
  needsUnlock,

  /// Beauty is on: that is part of the unlock, even for the free save.
  needsUnlockForBeauty,
}

/// Free: everything up to and including one saved photo (without beauty).
/// One-time unlock: unlimited saving and printing, beauty, reprints.
SaveDecision decideSave({required bool unlocked, required int freeSavesUsed, required bool beauty}) {
  if (unlocked) return SaveDecision.allowed;
  if (beauty) return SaveDecision.needsUnlockForBeauty;
  return freeSavesUsed < Purchases.freeSaves ? SaveDecision.allowed : SaveDecision.needsUnlock;
}

/// The one-time unlock, through StoreKit 2 in `AppDelegate.swift`.
///
/// Apple's signature is checked on the device, so a purchase or restore
/// unlocks without any server. The last known state is cached so the app
/// opens unlocked offline; StoreKit stays the source of truth and the cache
/// is corrected on every launch and on every transaction update.
class Purchases extends ChangeNotifier {
  Purchases(this._prefs, {MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vimai/photo'),
        _unlocked = _prefs.getBool(_unlockedKey) ?? false;

  static const freeSaves = 1;
  static const _unlockedKey = 'iap.unlocked';
  static const _freeKey = 'iap.freeSavesUsed';

  final SharedPreferences _prefs;
  final MethodChannel _channel;
  bool _unlocked;
  String? _price;

  bool get unlocked => _unlocked;

  /// Localized price from the App Store ("¥300", "$1.99"), null until loaded.
  String? get price => _price;

  int get freeSavesUsed => _prefs.getInt(_freeKey) ?? 0;

  SaveDecision canSave({required bool beauty}) =>
      decideSave(unlocked: _unlocked, freeSavesUsed: freeSavesUsed, beauty: beauty);

  /// Counts the free save; nothing to count once unlocked.
  Future<void> recordSave() async {
    if (_unlocked) return;
    await _prefs.setInt(_freeKey, freeSavesUsed + 1);
    notifyListeners();
  }

  /// Reads the real state from StoreKit and listens for later changes.
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'iapChanged') await _setUnlocked(call.arguments == true);
    });
    try {
      await _setUnlocked(await _channel.invokeMethod<bool>('iapUnlocked') ?? _unlocked);
      await loadPrice();
    } on MissingPluginException {
      // Not on iPhone (tests, Android for now): keep the cached state.
    } on PlatformException {
      // StoreKit unreachable: keep the cached state, try again later.
    }
  }

  Future<void> loadPrice() async {
    try {
      final p = await _channel.invokeMapMethod<String, Object?>('iapProduct');
      _price = p?['price'] as String?;
      notifyListeners();
    } on MissingPluginException {
      // Not on iPhone.
    } on PlatformException {
      // Shown as "price unavailable"; the sheet retries.
    }
  }

  Future<void> _setUnlocked(bool value) async {
    if (value == _unlocked) return;
    _unlocked = value;
    await _prefs.setBool(_unlockedKey, value);
    notifyListeners();
  }

  Future<PurchaseOutcome> buy() async {
    try {
      final r = await _channel.invokeMethod<String>('iapPurchase');
      switch (r) {
        case 'purchased':
          await _setUnlocked(true);
          return PurchaseOutcome.purchased;
        case 'pending':
          return PurchaseOutcome.pending;
        default:
          return PurchaseOutcome.cancelled;
      }
    } on PlatformException catch (e) {
      return switch (e.code) {
        'network' => PurchaseOutcome.network,
        'unavailable' => PurchaseOutcome.unavailable,
        'cancelled' => PurchaseOutcome.cancelled,
        _ => PurchaseOutcome.failed,
      };
    } on MissingPluginException {
      return PurchaseOutcome.unavailable;
    }
  }

  /// True when an earlier purchase was found on this Apple Account.
  Future<bool?> restore() async {
    try {
      final ok = await _channel.invokeMethod<bool>('iapRestore') ?? false;
      await _setUnlocked(ok);
      return ok;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

class PurchasesScope extends InheritedNotifier<Purchases> {
  const PurchasesScope({super.key, required Purchases purchases, required super.child})
      : super(notifier: purchases);

  static Purchases? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PurchasesScope>()?.notifier;
}
