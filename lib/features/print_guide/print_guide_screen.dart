import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/print_guide.dart';

/// "How to print": konbini steps and tips for getting the exact size.
class PrintGuideScreen extends StatelessWidget {
  const PrintGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navPrint), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l.printGuideIntro, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 14),
          Text(l.howToPrint, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const KonbiniSteps(),
          const SizedBox(height: 18),
          Text(l.printTipsTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _Tip(icon: Icons.crop_portrait, text: l.printTipSize),
                const Divider(height: 1, color: AppColors.well),
                _Tip(icon: Icons.crop_free, text: l.printStep2Body),
                const Divider(height: 1, color: AppColors.well),
                _Tip(icon: Icons.straighten, text: l.printTipMeasure),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.digitalHowTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l.digitalHowBody, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
      );
}
