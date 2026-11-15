import 'package:flutter/material.dart';

import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../l10n/app_localizations.dart';

/// Shows what the chosen document needs before the camera opens.
/// The camera itself arrives in phase 1.
class SpecDetailScreen extends StatelessWidget {
  const SpecDetailScreen({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(spec.nameFor(lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!spec.verified)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l.unverifiedWarning,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          _Row(
            label: l.sizeLabel,
            value: l.sizeValue(
              formatMm(spec.heightMm),
              formatMm(spec.widthMm),
            ),
          ),
          _Row(
            label: l.backgroundLabel,
            value: spec.backgrounds.map((b) => b.label(l)).join(' / '),
          ),
          _Row(
            label: l.validityLabel,
            value: l.validityMonths(spec.validityMonths),
          ),
          const SizedBox(height: 16),
          Text(l.rulesLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final rule in spec.rules)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(rule.label(l)),
            ),
          if (spec.sourceUrl != null) ...[
            const SizedBox(height: 8),
            Text(l.sourceLabel, style: theme.textTheme.labelLarge),
            SelectableText(
              spec.sourceUrl!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l.startCapture),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.captureComingSoon)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
