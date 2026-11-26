import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/capture/face_metrics.dart';
import '../../core/photo/beauty.dart';
import '../../core/photo/crop_geometry.dart';
import '../../core/photo/photo_analysis.dart';
import '../../core/photo/review_checks.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/flow_widgets.dart';
import 'processing_view.dart';
import '../sheet/sheet_screen.dart';
import '../../core/locale/locale_controller.dart';

/// Step 2 of 3: the photo already cut to the document's exact size, a
/// checklist against its rules, and the few adjustments that are allowed.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.spec,
    required this.shots,
    this.metrics = const [],
    this.best = 0,
    this.native = const PhotoNative(),
  });

  final PhotoSpec spec;

  /// Source photos (a burst from the camera, or one picked photo).
  final List<String> shots;

  /// ML Kit metrics per shot, same order as [shots]. May be shorter.
  final List<FaceMetrics?> metrics;
  final int best;
  final PhotoNative native;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

enum _Tab { background, frame, light, beauty }

class _ReviewScreenState extends State<ReviewScreen> {
  final _analyses = <String, PhotoAnalysis>{};
  late int _index = widget.best.clamp(0, widget.shots.length - 1);
  late PhotoBackground _bg = widget.spec.backgrounds.first;
  double _zoom = 1;
  double _shift = 0;
  double _exposure = 0;
  _Tab _tab = _Tab.background;
  bool _showChecks = false;

  String? _rendered;
  String? _beforePath;
  bool _showBefore = false;
  RenderResult? _render;
  ReviewResult? _result;

  /// Strict documents keep their background unless the user accepts the
  /// warning that the office may refuse an edited background.
  bool _strictBackgroundAccepted = false;

  /// Skin care: a default per document, tuned by the user. Strict
  /// documents start at zero and unlock only after a warning.
  late BeautySettings _beauty = defaultBeautyFor(editLevelFor(widget.spec));
  bool _strictBeautyAccepted = false;
  String? _error;
  bool _busy = false;
  int _ticket = 0;

  /// When the big preview scrolls away (while using the sliders), a small
  /// copy stays pinned in the corner so every change can still be seen.
  final _scroll = ScrollController();
  bool _pinPreview = false;

  EditLevel get _level => editLevelFor(widget.spec);
  bool get _replaceBackground =>
      _level != EditLevel.strict || _strictBackgroundAccepted;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pin = _scroll.offset > 260;
    if (pin != _pinPreview) setState(() => _pinPreview = pin);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _process());
  }

  FaceMetrics? get _metrics =>
      _index < widget.metrics.length ? widget.metrics[_index] : null;

  Future<void> _process() async {
    final l = AppLocalizations.of(context);
    final ticket = ++_ticket;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = widget.shots[_index];
      final analysis = _analyses[path] ??= await widget.native.analyze(path);
      final crop = cropFor(
        analysis,
        widget.spec,
        adjust: FramingAdjust(zoom: _zoom, shift: _shift),
      );
      if (crop == null) {
        if (ticket == _ticket) setState(() => _error = l.noFaceFound);
        return;
      }
      final px = widget.spec.pixelSize();
      final out = await widget.native.render(
        path: path,
        analysis: analysis,
        crop: crop,
        outWidth: px.width,
        outHeight: px.height,
        heightMm: widget.spec.heightMm,
        backgroundArgb: _bg.swatch.toARGB32(),
        replaceBackground: _replaceBackground,
        level: _level,
        exposure: _exposure,
        beauty: _beauty.isNone ? null : _beauty.toMap(),
        before: true,
      );
      if (ticket != _ticket || !mounted) return;
      setState(() {
        _rendered = out.path;
        _beforePath = out.beforePath;
        _render = out;
        _result = reviewPhoto(
          analysis,
          widget.spec,
          metrics: _metrics,
          render: out,
          replaceBackground: _replaceBackground,
        );
      });
    } on PhotoNativeUnavailable {
      if (ticket == _ticket && mounted) setState(() => _error = l.iosOnly);
    } catch (_) {
      if (ticket == _ticket && mounted) setState(() => _error = l.processFailed);
    } finally {
      if (ticket == _ticket && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSingle() async {
    final l = AppLocalizations.of(context);
    final path = _rendered;
    if (path == null) return;
    final ok = await widget.native.saveToPhotos(path);
    if (mounted) showSnack(context, ok ? l.savedToPhotos : l.saveFailed);
  }

  void _next() {
    final path = _rendered;
    if (path == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SheetScreen(
          spec: widget.spec,
          photoPath: path,
          sourcePath: widget.shots[_index],
          native: widget.native,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);
    final spec = widget.spec;

    if (_rendered == null && _error == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.procTitle)),
        body: ProcessingView(
          steps: [
            l.procFace,
            l.procLight,
            _replaceBackground ? l.procBackground : l.procBackgroundKeep,
            l.procCrop(formatMm(spec.widthMm), formatMm(spec.heightMm)),
            l.procCheck,
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.reviewTitle)),
      body: Column(
        children: [
          const StepHeader(current: 1),
          Expanded(
            child: Stack(
              children: [
                ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _PreviewWell(
                  spec: spec,
                  rendered: _showBefore && _beforePath != null ? _beforePath : _rendered,
                  busy: _busy,
                  error: _error,
                  shots: widget.shots,
                  selected: _index,
                  best: widget.best,
                  onSelect: (i) {
                    if (i == _index) return;
                    setState(() => _index = i);
                    _process();
                  },
                ),
                if (_beforePath != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: true, label: Text(l.beforeLabel)),
                        ButtonSegment(value: false, label: Text(l.afterLabel)),
                      ],
                      selected: {_showBefore},
                      onSelectionChanged: (v) => setState(() => _showBefore = v.first),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (_result != null)
                  _ChecksBanner(
                    result: _result!,
                    render: _render,
                    spec: spec,
                    docName: spec.nameFor(lang),
                    expanded: _showChecks,
                    onToggle: () => setState(() => _showChecks = !_showChecks),
                  ),
                if (isOfficialDocument(spec)) ...[
                  const SizedBox(height: 10),
                  _NoRetouchBadge(text: _beauty.isNone ? l.noFaceEditBadge : l.beautyLightBadge),
                ],
                const SizedBox(height: 14),
                _TabBar(
                  current: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: 12),
                _tabBody(l),
              ],
            ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: IgnorePointer(
                    ignoring: !_pinPreview,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _pinPreview && _rendered != null ? 1 : 0,
                      child: _PinnedPreview(
                        path: _rendered,
                        beforePath: _beforePath,
                        busy: _busy,
                        aspect: spec.widthMm / spec.heightMm,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomActions(
            children: [
              FilledButton(
                onPressed: _rendered == null || _busy ? null : _next,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(l.continueToSheet)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l.retake),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l.saveSingle),
                      onPressed: _rendered == null || _busy ? null : _saveSingle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBody(AppLocalizations l) {
    switch (_tab) {
      case _Tab.background:
        if (_level == EditLevel.strict && !_strictBackgroundAccepted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LockNote(text: l.bgStrictWarning),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {
                    setState(() => _strictBackgroundAccepted = true);
                    _process();
                  },
                  child: Text(l.bgStrictAccept),
                ),
              ),
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final b in widget.spec.backgrounds)
              _Swatch(
                color: b.swatch,
                label: b.label(l),
                selected: b == _bg,
                onTap: () {
                  setState(() => _bg = b);
                  _process();
                },
              ),
          ],
        );
      case _Tab.frame:
        return Column(
          children: [
            _SliderRow(
              label: l.frameZoom,
              value: _zoom,
              min: 0.9,
              max: 1.1,
              onChanged: (v) => setState(() => _zoom = v),
              onChangeEnd: (_) => _process(),
            ),
            _SliderRow(
              label: l.frameShift,
              value: _shift,
              min: -0.05,
              max: 0.05,
              onChanged: (v) => setState(() => _shift = v),
              onChangeEnd: (_) => _process(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _zoom = 1;
                    _shift = 0;
                  });
                  _process();
                },
                child: Text(l.resetLabel),
              ),
            ),
          ],
        );
      case _Tab.light:
        return _SliderRow(
          label: l.tabLight,
          value: _exposure,
          min: -0.6,
          max: 0.6,
          onChanged: (v) => setState(() => _exposure = v),
          onChangeEnd: (_) => _process(),
        );
      case _Tab.beauty:
        if (_level == EditLevel.strict && !_strictBeautyAccepted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LockNote(text: l.beautyStrictWarning),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => setState(() => _strictBeautyAccepted = true),
                  child: Text(l.beautyStrictAccept),
                ),
              ),
            ],
          );
        }
        Widget slider(String label, double value, BeautySettings Function(double) apply) => _SliderRow(
              label: label,
              value: value,
              min: 0,
              max: 1,
              showPercent: true,
              onChanged: (v) => setState(() => _beauty = apply(v)),
              onChangeEnd: (_) => _process(),
            );
        return Column(
          children: [
            slider(l.beautySmooth, _beauty.smooth, (v) => _beauty.copyWith(smooth: v)),
            slider(l.beautyBrighten, _beauty.brighten, (v) => _beauty.copyWith(brighten: v)),
            slider(l.beautyEven, _beauty.even, (v) => _beauty.copyWith(even: v)),
            slider(l.beautyShine, _beauty.shine, (v) => _beauty.copyWith(shine: v)),
            slider(l.beautySharpen, _beauty.sharpen, (v) => _beauty.copyWith(sharpen: v)),
            slider(l.beautyLips, _beauty.lips, (v) => _beauty.copyWith(lips: v)),
            Row(
              children: [
                Expanded(
                  child: Text(l.beautyNote, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _beauty = BeautySettings.none);
                    _process();
                  },
                  child: Text(l.beautyOff),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _beauty = defaultBeautyFor(_level == EditLevel.strict ? EditLevel.standard : _level));
                    _process();
                  },
                  child: Text(l.resetLabel),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _PreviewWell extends StatelessWidget {
  const _PreviewWell({
    required this.spec,
    required this.rendered,
    required this.busy,
    required this.error,
    required this.shots,
    required this.selected,
    required this.best,
    required this.onSelect,
  });

  final PhotoSpec spec;
  final String? rendered;
  final bool busy;
  final String? error;
  final List<String> shots;
  final int selected;
  final int best;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const photoH = 248.0;
    final photoW = photoH * spec.widthMm / spec.heightMm;

    Widget photo;
    if (error != null) {
      photo = Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ),
      );
    } else if (rendered == null) {
      photo = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(l.reviewProcessing, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      );
    } else {
      photo = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(rendered!), fit: BoxFit.cover, gaplessPlayback: true),
          if (busy) const ColoredBox(color: Color(0x55FFFFFF)),
          if (busy) const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.well, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Row(
                children: [
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text('${formatMm(spec.heightMm)} mm', style: _dimStyle),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: photoW,
                    height: photoH,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Color(0x2E0F2A30), blurRadius: 18, offset: Offset(0, 6))],
                    ),
                    child: photo,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${formatMm(spec.widthMm)} mm', style: _dimStyle),
            ],
          ),
          if (shots.length > 1) ...[
            const SizedBox(width: 14),
            Column(
              children: [
                Text(l.shotsLabel(shots.length), style: _dimStyle),
                const SizedBox(height: 8),
                for (var i = 0; i < shots.length; i++) ...[
                  _Thumb(
                    path: shots[i],
                    selected: i == selected,
                    best: i == best,
                    bestLabel: l.bestBadge,
                    onTap: () => onSelect(i),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _dimStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted);
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.path,
    required this.selected,
    required this.best,
    required this.bestLabel,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final bool best;
  final String bestLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: best ? bestLabel : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFCFDCDD),
              width: selected ? 3 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover, cacheWidth: 160),
              if (best)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      bestLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecksBanner extends StatelessWidget {
  const _ChecksBanner({
    required this.result,
    required this.render,
    required this.spec,
    required this.docName,
    required this.expanded,
    required this.onToggle,
  });

  final ReviewResult result;
  final RenderResult? render;
  final PhotoSpec spec;
  final String docName;
  final bool expanded;
  final VoidCallback onToggle;

  String _label(AppLocalizations l, ReviewCheck c) => switch (c) {
        ReviewCheck.size => l.rcSize(formatMm(spec.widthMm), formatMm(spec.heightMm)),
        ReviewCheck.head => _headLabel(l),
        ReviewCheck.background => l.rcBackground,
        ReviewCheck.onlyYou => l.rcOnlyYou,
        ReviewCheck.straight => l.rcStraight,
        ReviewCheck.eyes => l.rcEyes,
        ReviewCheck.light => l.rcLight,
      };

  String _headLabel(AppLocalizations l) {
    final mm = render?.headMm;
    if (mm == null) return l.rcHead;
    final (lo, hi) = headRangeMm(spec);
    return l.rcHeadMeasured(mm.toStringAsFixed(1), formatMm(lo), formatMm(hi));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = result.allPassed;
    final soft = ok ? AppColors.okSoft : AppColors.warnSoft;
    final ink = ok ? AppColors.okText : AppColors.warnText;
    final dot = ok ? AppColors.ok : AppColors.accent;

    return Material(
      color: soft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ok ? AppColors.okLine : const Color(0xFFF0D3A0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    child: Icon(ok ? Icons.check : Icons.priority_high, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ok ? l.passTitle(docName) : l.failTitle(result.failed.length),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
                        ),
                        Text(
                          l.passSub(result.passed, result.total),
                          style: TextStyle(fontSize: 12, color: ink),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: ink),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                for (final e in result.items.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        Icon(
                          e.value ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: e.value ? AppColors.ok : const Color(0xFFB86E00),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_label(l, e.key), style: const TextStyle(fontSize: 13, color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final _Tab current;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = {
      _Tab.background: l.tabBackground,
      _Tab.frame: l.tabFrame,
      _Tab.light: l.tabLight,
      _Tab.beauty: l.tabBeauty,
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.well, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final t in _Tab.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: t == current,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == current ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      labels[t]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: t == current ? FontWeight.w700 : FontWeight.w600,
                        color: t == current ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFB5C9D6),
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.showPercent = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final bool showPercent;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        if (showPercent)
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

class _NoRetouchBadge extends StatelessWidget {
  const _NoRetouchBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small copy of the result, pinned while the sliders are in view.
/// Press and hold to see the photo before correction.
class _PinnedPreview extends StatefulWidget {
  const _PinnedPreview({required this.path, required this.beforePath, required this.busy, required this.aspect});

  final String? path;
  final String? beforePath;
  final bool busy;
  final double aspect;

  @override
  State<_PinnedPreview> createState() => _PinnedPreviewState();
}

class _PinnedPreviewState extends State<_PinnedPreview> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    final path = _holding && widget.beforePath != null ? widget.beforePath : widget.path;
    const h = 150.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _holding = true),
      onTapUp: (_) => setState(() => _holding = false),
      onTapCancel: () => setState(() => _holding = false),
      child: Container(
        width: h * widget.aspect,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x400F2A30), blurRadius: 14, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null) Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true),
            if (widget.busy)
              const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
          ],
        ),
      ),
    );
  }
}
