import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/flow_widgets.dart';
import '../capture/capture_screen.dart';

/// Twenty seconds of setup before the camera: light, wall, hair, glasses,
/// and who holds the phone (which decides the camera).
class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  CameraLensDirection _lens = CameraLensDirection.back;

  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CaptureScreen(spec: widget.spec, initialLens: _lens),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final spec = widget.spec;

    return Scaffold(
      appBar: AppBar(title: Text(l.prepareTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(
            '${spec.nameFor(lang)} · ${formatMm(spec.widthMm)}×${formatMm(spec.heightMm)} mm',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          if (lang != 'ja')
            Text(spec.jaName, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 14),
          Text(l.prepareHeadline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 6),
          Text(l.prepareSub, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _Tip(icon: Icons.wb_sunny_outlined, title: l.tipLightTitle, body: l.tipLightBody),
                const Divider(height: 1, color: AppColors.well),
                _Tip(icon: Icons.straighten, title: l.tipWallTitle, body: l.tipWallBody),
                const Divider(height: 1, color: AppColors.well),
                _Tip(icon: Icons.face_retouching_off_outlined, title: l.tipHairTitle, body: l.tipHairBody),
                const Divider(height: 1, color: AppColors.well),
                _Tip(icon: Icons.visibility_outlined, title: l.tipGlassesTitle, body: l.tipGlassesBody),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l.whoHolds, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _LensOption(
            icon: Icons.people_outline,
            title: l.holdOther,
            body: l.holdOtherSub,
            badge: l.recommended,
            selected: _lens == CameraLensDirection.back,
            onTap: () => setState(() => _lens = CameraLensDirection.back),
          ),
          const SizedBox(height: 10),
          _LensOption(
            icon: Icons.person_outline,
            title: l.holdSelf,
            body: l.holdSelfSub,
            selected: _lens == CameraLensDirection.front,
            onTap: () => setState(() => _lens = CameraLensDirection.front),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: Text(l.startCapture),
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LensOption extends StatelessWidget {
  const _LensOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? badge;
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.okSoft, borderRadius: BorderRadius.circular(99)),
                              child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.okText)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(body, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
