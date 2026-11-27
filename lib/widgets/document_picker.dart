import 'package:flutter/material.dart';

import '../core/spec_l10n.dart';
import '../core/specs/photo_spec.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../core/locale/locale_controller.dart';

/// Bottom sheet listing the documents; returns the one tapped.
Future<PhotoSpec?> showDocumentPicker(
  BuildContext context,
  List<PhotoSpec> specs, {
  String? selectedId,
}) {
  final lang = langOf(context);
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<PhotoSpec>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l.chooseDocTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final s in specs)
              ListTile(
                leading: Icon(specIcon(s.icon)),
                title: Text(s.nameFor(lang)),
                subtitle: Text('${s.jaName} · ${formatMm(s.widthMm)}×${formatMm(s.heightMm)} mm'),
                trailing: s.id == selectedId ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    ),
  );
}
