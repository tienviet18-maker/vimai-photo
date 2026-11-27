import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/photo/crop_geometry.dart';
import '../../core/photo/photo_analysis.dart';
import '../../core/photo/review_checks.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/specs/spec_repository.dart';
import '../../core/theme.dart';
import '../../platform/photo_native.dart';

/// Developer tool: run the whole pipeline over a set of photos picked from
/// the library and show what the device measured on each result, so a
/// change to the processing can be judged on the same photos every time.
class TestSetScreen extends StatefulWidget {
  const TestSetScreen({super.key, this.native = const PhotoNative()});

  final PhotoNative native;

  @override
  State<TestSetScreen> createState() => _TestSetScreenState();
}

class _Row {
  _Row(this.source);

  final String source;
  PhotoAnalysis? analysis;
  RenderResult? render;
  ReviewResult? review;
  int? millis;
  String? error;
}

class _TestSetScreenState extends State<TestSetScreen> {
  List<PhotoSpec> _specs = const [];
  PhotoSpec? _spec;
  final _rows = <_Row>[];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    SpecRepository().load().then((specs) {
      if (!mounted) return;
      setState(() {
        _specs = specs;
        _spec = specs.first;
      });
    });
  }

  Future<void> _pick() async {
    final paths = await widget.native.pickPhotos();
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _rows
        ..clear()
        ..addAll(paths.map(_Row.new));
    });
    await _runAll();
  }

  Future<void> _runAll() async {
    final spec = _spec;
    if (spec == null) return;
    setState(() => _running = true);
    for (final row in _rows) {
      final watch = Stopwatch()..start();
      try {
        final a = await widget.native.analyze(row.source);
        row.analysis = a;
        final crop = cropFor(a, spec);
        if (crop == null) {
          row.error = 'no face';
        } else {
          final px = spec.pixelSize();
          final level = editLevelFor(spec);
          final out = await widget.native.render(
            path: row.source,
            analysis: a,
            crop: crop,
            outWidth: px.width,
            outHeight: px.height,
            heightMm: spec.heightMm,
            backgroundArgb: spec.backgrounds.first.swatch.toARGB32(),
            replaceBackground: true,
            level: level,
          );
          row.render = out;
          row.review = reviewPhoto(a, spec, render: out, replaceBackground: true);
        }
      } catch (e) {
        row.error = '$e';
      }
      row.millis = watch.elapsedMilliseconds;
      if (!mounted) return;
      setState(() {});
    }
    // Source images stay cached natively otherwise.
    await widget.native.clearCache();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final done = _rows.where((r) => r.review != null || r.error != null).toList();
    final passed = done.where((r) => r.review?.allPassed ?? false).length;
    final times = [for (final r in done) if (r.millis != null) r.millis!];
    final avg = times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Test set')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _specs)
                ChoiceChip(
                  label: Text(s.id),
                  selected: s == _spec,
                  onSelected: _running ? null : (_) => setState(() => _spec = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_rows.isEmpty ? 'Pick test photos' : 'Pick again'),
            onPressed: _running ? null : _pick,
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _running ? null : _runAll,
              child: const Text('Run again with this spec'),
            ),
            const SizedBox(height: 12),
            Text(
              '${done.length}/${_rows.length} done · $passed passed all checks · avg $avg ms',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final r in _rows) _ResultTile(row: r, spec: _spec!),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.row, required this.spec});

  final _Row row;
  final PhotoSpec spec;

  @override
  Widget build(BuildContext context) {
    final out = row.render;
    final review = row.review;
    String f(double? v, [int digits = 1]) => v == null ? '–' : v.toStringAsFixed(digits);
    final (lo, hi) = headRangeMm(spec);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              height: 90 * spec.heightMm / spec.widthMm,
              child: out == null
                  ? Image.file(File(row.source), fit: BoxFit.cover, cacheWidth: 200)
                  : GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _Zoom(path: out.path),
                        ),
                      ),
                      child: Image.file(File(out.path), fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (row.error != null)
                      Text('Error: ${row.error}', style: const TextStyle(color: Colors.red))
                    else if (review == null)
                      const Text('…')
                    else ...[
                      Text(
                        review.allPassed ? 'PASS' : 'FAIL: ${review.failed.map((c) => c.name).join(', ')}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: review.allPassed ? AppColors.ok : const Color(0xFFB86E00),
                        ),
                      ),
                      Text('head ${f(out?.headMm)} mm (${formatMm(lo)}–${formatMm(hi)}) · top ${f(out?.topMarginMm)} mm'),
                      Text('face luma ${f(out?.faceLuma, 0)} · balance ${f(out?.faceBalance, 2)}'),
                      Text('background spread ${f(out?.backgroundSpread)} · mask ${row.analysis?.hasMask}'),
                      Text('crown ${row.analysis?.crownY != null ? 'mask' : 'estimated'} · chin ${row.analysis?.chinY != null ? 'landmark' : 'box'}'),
                    ],
                    if (row.millis != null) Text('${row.millis} ms', style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Zoom extends StatelessWidget {
  const _Zoom({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(
        maxScale: 8,
        child: Center(child: Image.file(File(path), filterQuality: FilterQuality.none)),
      ),
    );
  }
}
