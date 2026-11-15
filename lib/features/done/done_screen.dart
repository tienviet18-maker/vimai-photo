import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/specs/photo_spec.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/flow_widgets.dart';

/// The sheet is in Photos: how to print it at a konbini, plus the digital
/// photo for online applications.
class DoneScreen extends StatelessWidget {
  const DoneScreen({
    super.key,
    required this.spec,
    required this.sheetPath,
    required this.photoPath,
    required this.paperLabel,
    required this.count,
    this.native = const PhotoNative(),
  });

  final PhotoSpec spec;
  final String sheetPath;
  final String photoPath;
  final String paperLabel;
  final int count;
  final PhotoNative native;

  void _home(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => _home(context),
            child: Text(l.doneAction, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Container(
                width: 88,
                height: 126,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x2E0F2A30), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Image.file(File(sheetPath), fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check, size: 18, color: Color(0xFF1F7A45)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.savedToPhotos,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F7A45)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(l.doneReady, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      l.doneSheetInfo(paperLabel, count, spec.nameFor(lang)),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(l.howToPrint, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _PrintStep(n: 1, title: l.printStep1Title, body: l.printStep1Body),
                  const Divider(height: 1, color: AppColors.well),
                  _PrintStep(n: 2, title: l.printStep2Title, body: l.printStep2Body),
                  const Divider(height: 1, color: AppColors.well),
                  _PrintStep(n: 3, title: l.printStep3Title, body: l.printStep3Body),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.download_outlined,
                  title: l.saveDigital,
                  subtitle: l.saveDigitalSub,
                  onTap: () async {
                    final ok = await native.saveToPhotos(photoPath);
                    if (context.mounted) showSnack(context, ok ? l.savedToPhotos : l.saveFailed);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.ios_share,
                  title: l.shareLabel,
                  subtitle: l.shareSub,
                  onTap: () => native.share(sheetPath),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => showSnack(context, l.proSoon),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const ProTag(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.proTitle, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(l.proSub, style: const TextStyle(color: AppColors.onPrimaryMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        children: [
          OutlinedButton(
            onPressed: () => _home(context),
            child: Text(l.anotherDoc),
          ),
        ],
      ),
    );
  }
}

class _PrintStep extends StatelessWidget {
  const _PrintStep({required this.n, required this.title, required this.body});

  final int n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFCFDCDD)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
