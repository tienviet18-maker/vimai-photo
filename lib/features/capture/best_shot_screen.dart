import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/specs/photo_spec.dart';
import '../../l10n/app_localizations.dart';

/// Shows the shot picked from the burst. Phase 2 adds background removal
/// and exact cropping here.
class BestShotScreen extends StatelessWidget {
  const BestShotScreen({
    super.key,
    required this.spec,
    required this.photoPath,
    required this.shotCount,
  });

  final PhotoSpec spec;
  final String photoPath;
  final int shotCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.bestShotTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(photoPath), fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text(l.bestShotBody(shotCount), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            l.nextStepPhase2,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(l.retake),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
