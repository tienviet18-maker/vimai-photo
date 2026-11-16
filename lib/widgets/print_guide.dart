import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// The three konbini steps, used after saving and in the "How to print" tab.
class KonbiniSteps extends StatelessWidget {
  const KonbiniSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            PrintStep(n: 1, title: l.printStep1Title, body: l.printStep1Body),
            const Divider(height: 1, color: AppColors.well),
            PrintStep(n: 2, title: l.printStep2Title, body: l.printStep2Body),
            const Divider(height: 1, color: AppColors.well),
            PrintStep(n: 3, title: l.printStep3Title, body: l.printStep3Body),
          ],
        ),
      ),
    );
  }
}

class PrintStep extends StatelessWidget {
  const PrintStep({required this.n, required this.title, required this.body});

  final int n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

