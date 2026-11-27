import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/purchase/purchases.dart';
import '../../widgets/flow_widgets.dart';
import '../paywall/paywall_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../debug/test_set_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.localeController});

  final LocaleController localeController;


  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) {
          final current = localeController.locale?.toLanguageTag();
          return RadioGroup<String?>(
            groupValue: current,
            onChanged: (code) => localeController
                .setLocale(code == null
                    ? null
                    : LocaleController.supported.firstWhere((l) => l.toLanguageTag() == code)),
            child: ListView(
              children: [
                ListTile(
                  title: Text(
                    l.languageLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                RadioListTile<String?>(
                  value: null,
                  title: Text(l.languageSystem),
                ),
                for (final locale in LocaleController.supported)
                  RadioListTile<String?>(
                    value: locale.toLanguageTag(),
                    title: Text(LocaleController.nativeNames[locale.toLanguageTag()]!),
                  ),
                const Divider(),
                const _PurchaseTile(),
                // Developer tool: batch-process a set of photos and show the
                // measurements. Not shown in store builds.
                if (!kReleaseMode) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('Test set (developer)'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TestSetScreen()),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Unlock status, buy, and restore an earlier purchase.
class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final purchases = PurchasesScope.maybeOf(context);
    if (purchases == null) return const SizedBox.shrink();
    if (purchases.unlocked) {
      return ListTile(
        leading: const Icon(Icons.verified_outlined, color: Colors.green),
        title: Text(l.payUnlockedTitle),
        subtitle: Text(l.payUnlockedSub),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l.payTitle),
          subtitle: Text(purchases.price == null ? l.payOneTime : '${purchases.price} · ${l.payOneTime}'),
          onTap: () => showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Colors.white,
            builder: (_) => PaywallSheet(purchases: purchases, reason: SaveDecision.needsUnlock),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(l.restoreButton),
          onTap: () async {
            final found = await purchases.restore();
            if (!context.mounted) return;
            showSnack(context, found == true ? l.restoreFound : found == null ? l.payNetwork : l.restoreNone);
          },
        ),
      ],
    );
  }
}
