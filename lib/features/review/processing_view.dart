import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Shown while the first render runs: what the app is doing, step by step.
/// Steps tick on a timer and the last one waits for the real result, so the
/// list never claims to be finished before the photo is.
class ProcessingView extends StatefulWidget {
  const ProcessingView({super.key, required this.steps});

  final List<String> steps;

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView> {
  int _done = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 550), (t) {
      if (_done >= widget.steps.length - 1) {
        t.cancel();
        return;
      }
      setState(() => _done++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: SizedBox.square(dimension: 56, child: CircularProgressIndicator(strokeWidth: 4)),
              ),
              const SizedBox(height: 18),
              Text(
                l.procTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l.procTime,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.steps.length; i++)
                        _StepRow(
                          text: widget.steps[i],
                          state: i < _done
                              ? _StepState.done
                              : i == _done
                                  ? _StepState.active
                                  : _StepState.waiting,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.procPrivacy,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, active, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.text, required this.state});

  final String text;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (state) {
      _StepState.done => const Icon(Icons.check_circle, size: 22, color: AppColors.ok),
      _StepState.active => const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      _StepState.waiting => const Icon(Icons.radio_button_unchecked, size: 22, color: Color(0xFFB8C7C9)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: mark)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: state == _StepState.active ? FontWeight.w700 : FontWeight.w500,
                color: state == _StepState.waiting ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
