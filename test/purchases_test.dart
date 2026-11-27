import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimai_photo/core/purchase/purchases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decideSave', () {
    test('first save is free, the second needs the unlock', () {
      expect(decideSave(unlocked: false, freeSavesUsed: 0, beauty: false), SaveDecision.allowed);
      expect(decideSave(unlocked: false, freeSavesUsed: 1, beauty: false), SaveDecision.needsUnlock);
    });

    test('beauty always needs the unlock', () {
      expect(decideSave(unlocked: false, freeSavesUsed: 0, beauty: true), SaveDecision.needsUnlockForBeauty);
    });

    test('unlocked saves anything', () {
      expect(decideSave(unlocked: true, freeSavesUsed: 9, beauty: true), SaveDecision.allowed);
    });
  });

  group('Purchases', () {
    const channel = MethodChannel('vimai/photo');
    late List<String> calls;

    void answer(Object? Function(String method) reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final r = reply(call.method);
        if (r is PlatformException) throw r;
        return r;
      });
    }

    setUp(() {
      calls = [];
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('start reads StoreKit, overriding a stale cache', () async {
      SharedPreferences.setMockInitialValues({'iap.unlocked': true});
      final prefs = await SharedPreferences.getInstance();
      answer((m) => m == 'iapUnlocked' ? false : {'price': '¥300', 'name': 'Unlock'});
      final p = Purchases(prefs);
      expect(p.unlocked, isTrue);
      await p.start();
      expect(p.unlocked, isFalse, reason: 'a refund or another account must lock again');
      expect(p.price, '¥300');
    });

    test('purchase unlocks and is remembered', () async {
      final prefs = await SharedPreferences.getInstance();
      answer((m) => m == 'iapPurchase' ? 'purchased' : null);
      final p = Purchases(prefs);
      expect(await p.buy(), PurchaseOutcome.purchased);
      expect(p.unlocked, isTrue);
      expect(Purchases(prefs).unlocked, isTrue);
    });

    test('cancel, pending and network errors keep it locked', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = Purchases(prefs);
      answer((m) => 'cancelled');
      expect(await p.buy(), PurchaseOutcome.cancelled);
      answer((m) => 'pending');
      expect(await p.buy(), PurchaseOutcome.pending);
      answer((m) => PlatformException(code: 'network'));
      expect(await p.buy(), PurchaseOutcome.network);
      answer((m) => PlatformException(code: 'unverified'));
      expect(await p.buy(), PurchaseOutcome.failed);
      expect(p.unlocked, isFalse);
    });

    test('restore reports whether a purchase was found', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = Purchases(prefs);
      answer((m) => true);
      expect(await p.restore(), isTrue);
      expect(p.unlocked, isTrue);
      answer((m) => PlatformException(code: 'failed'));
      expect(await p.restore(), isNull);
      expect(p.unlocked, isTrue, reason: 'a failed restore must not lock a paid user');
    });

    test('free save is counted once, not after unlocking', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = Purchases(prefs);
      await p.recordSave();
      expect(p.freeSavesUsed, 1);
      expect(p.canSave(beauty: false), SaveDecision.needsUnlock);
      answer((m) => 'purchased');
      await p.buy();
      await p.recordSave();
      expect(p.freeSavesUsed, 1);
      expect(p.canSave(beauty: true), SaveDecision.allowed);
    });
  });
}
