import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/layout/print_sheet_layout.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/store/photo_store.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/flow_widgets.dart';
import '../done/done_screen.dart';

enum PaperSize { l, twoL }

extension PaperSizeX on PaperSize {
  SheetSize get sheet => this == PaperSize.l ? SheetSize.lSize : SheetSize.twoL;
  String label(AppLocalizations l) => this == PaperSize.l ? l.paperL : l.paper2L;
}

/// What the photo is for: a konbini print sheet, or the photo file itself.
enum SheetOutput { sheetL, sheet2L, digital }

extension SheetOutputX on SheetOutput {
  PaperSize? get paper => switch (this) {
        SheetOutput.sheetL => PaperSize.l,
        SheetOutput.sheet2L => PaperSize.twoL,
        SheetOutput.digital => null,
      };
}

/// Step 3 of 3: save the photo the way it will be used.
class SheetScreen extends StatefulWidget {
  const SheetScreen({
    super.key,
    required this.spec,
    required this.photoPath,
    this.sourcePath,
    this.savedPhoto,
    this.native = const PhotoNative(),
  });

  final PhotoSpec spec;

  /// The finished photo at print size.
  final String photoPath;

  /// The original shot, kept with the photo so it can be remade later.
  final String? sourcePath;

  /// Set when reprinting from My photos: nothing new is stored.
  final SavedPhoto? savedPhoto;
  final PhotoNative native;

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  SheetOutput _output = SheetOutput.sheetL;
  bool _guides = true;
  String? _sheetPath;
  bool _busy = false;
  bool _saving = false;
  int _ticket = 0;

  PrintSheetLayout _layoutFor(PaperSize p) =>
      PrintSheetLayout.grid(spec: widget.spec, sheet: p.sheet);

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final paper = _output.paper;
    if (paper == null) {
      setState(() => _sheetPath = null);
      return;
    }
    final ticket = ++_ticket;
    setState(() => _busy = true);
    final layout = _layoutFor(paper);
    final sheetPx = layout.sheet.pixelSize();
    final photoPx = widget.spec.pixelSize();
    try {
      final out = await widget.native.renderSheet(
        photoPath: widget.photoPath,
        sheetWidth: sheetPx.width,
        sheetHeight: sheetPx.height,
        photoWidth: photoPx.width,
        photoHeight: photoPx.height,
        slots: [
          for (final s in layout.slots)
            (mmToPx(s.leftMm).toDouble(), mmToPx(s.topMm).toDouble()),
        ],
        cutGuides: _guides,
      );
      if (ticket == _ticket && mounted) setState(() => _sheetPath = out);
    } catch (_) {
      if (mounted) showSnack(context, AppLocalizations.of(context).processFailed);
    } finally {
      if (ticket == _ticket && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final paper = _output.paper;
    final path = paper == null ? widget.photoPath : _sheetPath;
    if (path == null) return;
    setState(() => _saving = true);
    final ok = await widget.native.saveToPhotos(path);
    SavedPhoto? saved = widget.savedPhoto;
    if (ok && saved == null && mounted) {
      final store = PhotoStoreScope.maybeOf(context);
      try {
        saved = await store?.add(
          specId: widget.spec.id,
          photoPath: widget.photoPath,
          sourcePath: widget.sourcePath,
        );
      } on FileSystemException {
        saved = null;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, l.saveFailed);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoneScreen(
          spec: widget.spec,
          sheetPath: paper == null ? null : path,
          photoPath: widget.photoPath,
          paperLabel: paper?.label(l),
          count: paper == null ? 1 : _layoutFor(paper).count,
          saved: saved,
          native: widget.native,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final spec = widget.spec;
    final paper = _output.paper;
    final photoPx = spec.pixelSize();

    String subtitle(SheetOutput o) {
      switch (o) {
        case SheetOutput.sheetL:
        case SheetOutput.sheet2L:
          final layout = _layoutFor(o.paper!);
          final px = layout.sheet.pixelSize();
          return o == SheetOutput.sheetL
              ? l.outLSub(layout.count, px.width, px.height)
              : l.out2LSub(layout.count, px.width, px.height);
        case SheetOutput.digital:
          return l.outDigitalSub(photoPx.width, photoPx.height, formatMm(spec.widthMm), formatMm(spec.heightMm));
      }
    }

    String title(SheetOutput o) => switch (o) {
          SheetOutput.sheetL => l.outL,
          SheetOutput.sheet2L => l.out2L,
          SheetOutput.digital => l.outDigital,
        };

    IconData icon(SheetOutput o) => switch (o) {
          SheetOutput.sheetL => Icons.storefront_outlined,
          SheetOutput.sheet2L => Icons.grid_view,
          SheetOutput.digital => Icons.phone_iphone,
        };

    final Widget preview;
    if (paper == null) {
      const h = 220.0;
      preview = SizedBox(
        height: 300,
        child: Center(
          child: Container(
            width: h * spec.widthMm / spec.heightMm,
            height: h,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x330F2A30), blurRadius: 22, offset: Offset(0, 8))],
            ),
            child: Image.file(File(widget.photoPath), fit: BoxFit.cover),
          ),
        ),
      );
    } else {
      final sheet = paper.sheet;
      preview = SizedBox(
        height: 300,
        child: Center(
          child: AspectRatio(
            aspectRatio: sheet.widthMm / sheet.heightMm,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x330F2A30), blurRadius: 22, offset: Offset(0, 8))],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_sheetPath != null)
                    Image.file(File(_sheetPath!), fit: BoxFit.contain, gaplessPlayback: true),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.sheetTitle)),
      body: Column(
        children: [
          const StepHeader(current: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  decoration: BoxDecoration(color: AppColors.well, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    children: [
                      preview,
                      const SizedBox(height: 10),
                      Text(
                        paper == null
                            ? '${formatMm(spec.widthMm)}×${formatMm(spec.heightMm)} mm · ${photoPx.width}×${photoPx.height} px · 300 dpi'
                            : l.sheetInfo(
                                paper.label(l),
                                formatMm(paper.sheet.widthMm),
                                formatMm(paper.sheet.heightMm),
                                _layoutFor(paper).count,
                              ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(l.outputQuestion, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final o in SheetOutput.values) ...[
                  _OutputOption(
                    icon: icon(o),
                    title: title(o),
                    subtitle: subtitle(o),
                    selected: o == _output,
                    onTap: () {
                      if (o == _output) return;
                      setState(() => _output = o);
                      _render();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (paper != null)
                  Card(
                    child: SwitchListTile.adaptive(
                      title: Text(l.cutGuides, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      value: _guides,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) {
                        setState(() => _guides = v);
                        _render();
                      },
                    ),
                  ),
              ],
            ),
          ),
          BottomActions(
            children: [
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download, size: 20),
                label: Text(l.saveToPhotosAction),
                onPressed: _saving || (paper != null && (_sheetPath == null || _busy)) ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputOption extends StatelessWidget {
  const _OutputOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFFCFDCDD),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
