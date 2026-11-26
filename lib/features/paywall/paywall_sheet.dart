import 'package:flutter/material.dart';

import '../../core/purchase/purchases.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/flow_widgets.dart';

/// Asks before saving when the save needs the unlock. True when saving
/// may go ahead (already unlocked, or just bought or restored).
Future<bool> ensureCanSave(BuildContext context, {required bool beauty}) async {
  final purchases = PurchasesScope.maybeOf(context);
  if (purchases == null) return true;
  final decision = purchases.canSave(beauty: beauty);
  if (decision == SaveDecision.allowed) return true;
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => PaywallSheet(purchases: purchases, reason: decision),
  );
  return unlocked == true;
}

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key, required this.purchases, required this.reason});

  final Purchases purchases;
  final SaveDecision reason;

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _buying = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    if (widget.purchases.price == null) widget.purchases.loadPrice();
  }

  Future<void> _buy() async {
    final l = AppLocalizations.of(context);
    setState(() => _buying = true);
    final outcome = await widget.purchases.buy();
    if (!mounted) return;
    setState(() => _buying = false);
    switch (outcome) {
      case PurchaseOutcome.purchased:
        showSnack(context, l.payThanks);
        Navigator.of(context).pop(true);
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.pending:
        showSnack(context, l.payPending);
      case PurchaseOutcome.network:
        showSnack(context, l.payNetwork);
      case PurchaseOutcome.unavailable:
        showSnack(context, l.payUnavailable);
      case PurchaseOutcome.failed:
        showSnack(context, l.payFailed);
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    setState(() => _restoring = true);
    final found = await widget.purchases.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (found == true) {
      showSnack(context, l.restoreFound);
      Navigator.of(context).pop(true);
    } else {
      showSnack(context, found == null ? l.payNetwork : l.restoreNone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final price = widget.purchases.price;
    final busy = _buying || _restoring;

    return ListenableBuilder(
      listenable: widget.purchases,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.workspace_premium_outlined, size: 34, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.payTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reason == SaveDecision.needsUnlockForBeauty ? l.payWhyBeauty : l.payWhyFree,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              _Benefit(icon: Icons.all_inclusive, text: l.payBenefitSave),
              _Benefit(icon: Icons.auto_awesome_outlined, text: l.payBenefitBeauty),
              _Benefit(icon: Icons.photo_library_outlined, text: l.payBenefitPhotos),
              _Benefit(icon: Icons.block, text: l.payBenefitNoAds),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: busy || price == null ? null : _buy,
                child: _buying
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(price == null ? l.payLoadingPrice : l.payButton(price)),
              ),
              const SizedBox(height: 6),
              Text(
                l.payOneTime,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: busy ? null : _restore,
                child: _restoring
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.restoreButton),
              ),
              if (widget.reason == SaveDecision.needsUnlockForBeauty)
                Text(
                  l.payBeautyFreeHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3))),
        ],
      ),
    );
  }
}
