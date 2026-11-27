import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/layout/print_sheet_layout.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
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

/// Step 3 of 3: copies of the photo laid out on a convenience-store print.
class SheetScreen extends StatefulWidget {
  const SheetScreen({
    super.key,
    required this.spec,
    required this.photoPath,
    this.native = const PhotoNative(),
  });

  final PhotoSpec spec;
  final String photoPath;
  final PhotoNative native;

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  PaperSize _paper = PaperSize.l;
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
    final ticket = ++_ticket;
    setState(() => _busy = true);
    final layout = _layoutFor(_paper);
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
    final path = _sheetPath;
    if (path == null) return;
    setState(() => _saving = true);
    final ok = await widget.native.saveToPhotos(path);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, l.saveFailed);
      return;
    }
    final layout = _layoutFor(_paper);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoneScreen(
          spec: widget.spec,
          sheetPath: path,
          photoPath: widget.photoPath,
          paperLabel: _paper.label(l),
          count: layout.count,
          native: widget.native,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final layout = _layoutFor(_paper);
    final sheet = layout.sheet;

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
                      SizedBox(
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
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l.sheetInfo(
                          _paper.label(l),
                          formatMm(_paper.sheet.widthMm),
                          formatMm(_paper.sheet.heightMm),
                          layout.count,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(l.paperLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final p in PaperSize.values) ...[
                      if (p != PaperSize.l) const SizedBox(width: 10),
                      Expanded(
                        child: _PaperOption(
                          title: p.label(l),
                          subtitle: p == PaperSize.l
                              ? l.paperCheapest(_layoutFor(p).count)
                              : l.paperCount(_layoutFor(p).count),
                          selected: p == _paper,
                          onTap: () {
                            if (p == _paper) return;
                            setState(() => _paper = p);
                            _render();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: Text(l.cutGuides, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        value: _guides,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) {
                          setState(() => _guides = v);
                          _render();
                        },
                      ),
                      const Divider(height: 1, color: AppColors.well),
                      ListTile(
                        title: Text(l.mixSizes, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(l.mixSizesSub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        trailing: const ProTag(),
                        onTap: () => showSnack(context, l.proSoon),
                      ),
                    ],
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
                label: Text(l.saveSheet),
                onPressed: _sheetPath == null || _busy || _saving ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaperOption extends StatelessWidget {
  const _PaperOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
