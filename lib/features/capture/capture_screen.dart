import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/capture/capture_checks.dart';
import '../../core/capture/face_metrics.dart';
import '../../core/capture/voice_coach.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../review/review_screen.dart';
import 'face_analyzer.dart';

/// Step 2 of 3: live checks, then an automatic burst once every light has
/// stayed green for a moment.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  static const _burstCount = 3;

  final _analyzer = FaceAnalyzer();
  final _gate = StabilityGate();
  final _coach = VoiceCoach();
  final _tts = FlutterTts();

  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  CameraLensDirection _lens = CameraLensDirection.front;
  CaptureEvaluation? _eval;
  bool _busy = false;
  bool _capturing = false;
  bool _voice = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    _tts.setLanguage(switch (lang) { 'vi' => 'vi-VN', 'ja' => 'ja-JP', _ => 'en-US' });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _analyzer.close();
    _tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
      _gate.reset();
      _coach.reset();
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    if (_busy || _capturing || controller == null) return;
    _busy = true;
    try {
      final metrics = await _analyzer.analyzeFrame(
        image,
        controller.description,
        DeviceOrientation.portraitUp,
      );
      if (metrics == null || !mounted) return;
      final eval = _forLens(evaluateFrame(metrics));
      final now = DateTime.now();
      final fire = _gate.update(eval, now);
      setState(() => _eval = eval);
      _speak(eval.allPassed ? CaptureHint.holdStill : eval.primaryHint, now);
      if (fire) unawaited(_burst());
    } finally {
      _busy = false;
    }
  }

  /// With the rear camera someone else holds the phone, so left and right
  /// are said from the subject's side.
  CaptureEvaluation _forLens(CaptureEvaluation e) {
    if (_lens == CameraLensDirection.front) return e;
    CaptureHint swap(CaptureHint h) => switch (h) {
          CaptureHint.moveLeft => CaptureHint.moveRight,
          CaptureHint.moveRight => CaptureHint.moveLeft,
          _ => h,
        };
    return CaptureEvaluation(e.passed, e.hints.map(swap).toList());
  }

  void _speak(CaptureHint? hint, DateTime now) {
    if (!_voice) return;
    final say = _coach.next(hint, now);
    if (say == null) return;
    _tts.speak(say.label(AppLocalizations.of(context)));
  }

  Future<void> _burst() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      await controller.stopImageStream();
      await HapticFeedback.mediumImpact();
      final shots = <XFile>[];
      for (var i = 0; i < _burstCount; i++) {
        shots.add(await controller.takePicture());
      }
      final metrics = <FaceMetrics>[
        for (final s in shots) await _analyzer.analyzeFile(s.path),
      ];
      final best = pickBest(metrics) ?? 0;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewScreen(
            spec: widget.spec,
            shots: [for (final s in shots) s.path],
            metrics: metrics,
            best: best,
          ),
        ),
      );
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        _gate.reset();
        final c = _controller;
        if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
          await c.startImageStream(_onFrame);
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    final old = _controller;
    setState(() {
      _controller = null;
      _eval = null;
      _lens = _lens == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    await old?.dispose();
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.spec.nameFor(Localizations.localeOf(context).languageCode)),
        actions: [
          IconButton(
            tooltip: _voice ? l.voiceOff : l.voiceOn,
            icon: Icon(_voice ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _voice = !_voice);
              if (!_voice) _tts.stop();
            },
          ),
          if (_cameras.length > 1)
            IconButton(
              tooltip: l.switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _capturing ? null : _switchCamera,
            ),
        ],
      ),
      body: _error != null
          ? _ErrorView(error: _error!)
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : _CameraView(
                  controller: controller,
                  eval: _eval,
                  capturing: _capturing,
                  progress: _gate.progress(DateTime.now()),
                  onShutter: _capturing ? null : _burst,
                ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({
    required this.controller,
    required this.eval,
    required this.capturing,
    required this.progress,
    required this.onShutter,
  });

  final CameraController controller;
  final CaptureEvaluation? eval;
  final bool capturing;
  final double progress;
  final VoidCallback? onShutter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ok = eval?.allPassed ?? false;
    final hint = capturing
        ? l.capturing
        : ok
            ? l.hintHoldStill
            : eval?.primaryHint?.label(l) ?? '';

    return Column(
      children: [
        _HintBanner(text: hint, ok: ok),
        Expanded(
          child: Center(
            child: AspectRatio(
              // Preview size is reported landscape; the screen is portrait.
              aspectRatio: 1 / controller.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  CustomPaint(painter: _GuidePainter(ok: ok)),
                ],
              ),
            ),
          ),
        ),
        _CheckLights(passed: eval?.passed ?? const {}),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: _ShutterButton(progress: progress, onPressed: onShutter, label: l.shutter),
        ),
      ],
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: ok ? AppColors.ok : Colors.black,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Oval where the head should sit; turns green when everything passes.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.ok});

  final bool ok;

  @override
  void paint(Canvas canvas, Size size) {
    // Matches CaptureThresholds: centre at 42% height, face ~0.28–0.50 tall.
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.52,
      height: size.height * 0.50,
    );
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = ok ? AppColors.ok : Colors.white70,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.ok != ok;
}

class _CheckLights extends StatelessWidget {
  const _CheckLights({required this.passed});

  final Set<CaptureCheck> passed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in CaptureCheck.values)
            _Light(label: c.label(l), on: passed.contains(c)),
        ],
      ),
    );
  }
}

class _Light extends StatelessWidget {
  const _Light({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? AppColors.ok : Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.check_circle : Icons.circle_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.progress, required this.onPressed, required this.label});

  final double progress;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  color: AppColors.ok,
                  backgroundColor: Colors.white24,
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onPressed == null ? Colors.white38 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final denied = error is CameraException &&
        (error as CameraException).code.contains('AccessDenied');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          denied ? l.cameraDenied : l.cameraError,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
