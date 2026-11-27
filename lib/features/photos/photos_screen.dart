import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/store/photo_store.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/document_picker.dart';
import '../../widgets/flow_widgets.dart';
import '../prepare/prepare_screen.dart';
import '../review/review_screen.dart';
import '../sheet/sheet_screen.dart';
import '../../core/locale/locale_controller.dart';

/// Actions on a saved photo, shared by My photos and the home screen.
class SavedPhotoActions {
  const SavedPhotoActions(this.context, this.specs, {this.native = const PhotoNative()});

  final BuildContext context;
  final List<PhotoSpec> specs;
  final PhotoNative native;

  PhotoSpec? specOf(SavedPhoto p) => specs.where((s) => s.id == p.specId).firstOrNull;

  Future<void> reprint(PhotoStore store, SavedPhoto p) async {
    final spec = specOf(p);
    if (spec == null) return;
    final path = await store.pathOf(p.photoFile);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SheetScreen(spec: spec, photoPath: path, savedPhoto: p, native: native),
      ),
    );
  }

  /// Makes the photo again from the original shot for another document.
  Future<void> otherDocument(PhotoStore store, SavedPhoto p) async {
    final l = AppLocalizations.of(context);
    final source = p.sourceFile == null ? null : await store.pathOf(p.sourceFile!);
    if (!context.mounted) return;
    if (source == null || !File(source).existsSync()) {
      showSnack(context, l.sourceMissing);
      return;
    }
    final spec = await showDocumentPicker(context, specs, selectedId: p.specId);
    if (spec == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(spec: spec, shots: [source], native: native),
      ),
    );
  }

  void retake(SavedPhoto p) {
    final spec = specOf(p);
    if (spec == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PrepareScreen(spec: spec)),
    );
  }

  Future<void> delete(PhotoStore store, SavedPhoto p) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancelLabel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.deleteLabel)),
        ],
      ),
    );
    if (yes != true) return;
    if (p.remind) {
      try {
        await native.cancelReminder('photo-${p.id}');
      } on PhotoNativeUnavailable {
        // Nothing was scheduled off iOS.
      }
    }
    await store.remove(p);
  }
}

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key, required this.specs});

  final List<PhotoSpec> specs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = PhotoStoreScope.maybeOf(context);
    final items = store?.items ?? const <SavedPhoto>[];
    final actions = SavedPhotoActions(context, specs);

    return Scaffold(
      appBar: AppBar(title: Text(l.navPhotos), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l.photosSub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 14),
          if (items.isEmpty || store == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text(l.photosEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            )
          else
            FutureBuilder<String>(
              future: store.folder(),
              builder: (context, snap) {
                final dir = snap.data;
                if (dir == null) return const SizedBox(height: 80);
                return Column(
                  children: [
                    for (final p in items)
                      if (actions.specOf(p) case final spec?) ...[
                        SavedPhotoCard(
                          photo: p,
                          spec: spec,
                          folder: dir,
                          onReprint: () => actions.reprint(store, p),
                          onOtherDoc: () => actions.otherDocument(store, p),
                          onRetake: () => actions.retake(p),
                          onDelete: () => actions.delete(store, p),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(l.photosFooter, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4))),
            ],
          ),
        ],
      ),
    );
  }
}

// The theme makes buttons full width; inside a Wrap they must size to fit.
final _compactFilled = FilledButton.styleFrom(minimumSize: const Size(0, 40));
final _compactOutlined = OutlinedButton.styleFrom(minimumSize: const Size(0, 40));

class SavedPhotoCard extends StatelessWidget {
  const SavedPhotoCard({
    super.key,
    required this.photo,
    required this.spec,
    required this.folder,
    required this.onReprint,
    required this.onOtherDoc,
    required this.onRetake,
    required this.onDelete,
  });

  final SavedPhoto photo;
  final PhotoSpec spec;
  final String folder;
  final VoidCallback onReprint;
  final VoidCallback onOtherDoc;
  final VoidCallback onRetake;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);
    final now = DateTime.now();
    final expiry = expiryOf(photo.takenAt, spec.validityMonths);
    final status = expiryStatus(expiry, now);
    final left = monthsLeft(expiry, now);

    final (Color bg, Color fg, String label) = switch (status) {
      ExpiryStatus.valid => (AppColors.okSoft, AppColors.okText, left >= 1 ? l.monthsLeft(left) : l.lessThanMonth),
      ExpiryStatus.soon => (AppColors.warnSoft, AppColors.warnText, left >= 1 ? l.monthsLeft(left) : l.lessThanMonth),
      ExpiryStatus.expired => (const Color(0xFFFDECEC), const Color(0xFF8A1C1C), l.expiredLabel(spec.validityMonths)),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60 * spec.heightMm / spec.widthMm,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.line)),
                  child: Image.file(
                    File('$folder/${photo.photoFile}'),
                    fit: BoxFit.cover,
                    cacheWidth: 180,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${spec.nameFor(lang)} · ${formatMm(spec.widthMm)}×${formatMm(spec.heightMm)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(l.takenOn(formatDate(photo.takenAt, lang)), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
                        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.deleteLabel,
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == ExpiryStatus.valid)
                  FilledButton.tonal(style: _compactFilled, onPressed: onReprint, child: Text(l.reprint))
                else
                  FilledButton.tonal(style: _compactFilled, onPressed: onRetake, child: Text(l.newPhoto)),
                if (status != ExpiryStatus.valid) OutlinedButton(style: _compactOutlined, onPressed: onReprint, child: Text(l.reprint)),
                if (photo.sourceFile != null) OutlinedButton(style: _compactOutlined, onPressed: onOtherDoc, child: Text(l.useOtherDoc)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
