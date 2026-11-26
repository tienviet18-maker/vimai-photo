import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/store/photo_store.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/flow_widgets.dart';
import '../../widgets/print_guide.dart';

/// Saved to Photos: how to use it (konbini print or online application),
/// how long the photo stays valid, and a reminder before it runs out.
class DoneScreen extends StatefulWidget {
  const DoneScreen({
    super.key,
    required this.spec,
    required this.photoPath,
    this.sheetPath,
    this.paperLabel,
    this.count = 1,
    this.saved,
    this.native = const PhotoNative(),
  });

  final PhotoSpec spec;

  /// Null when only the digital photo was saved.
  final String? sheetPath;
  final String photoPath;
  final String? paperLabel;
  final int count;

  /// The entry in My photos, when it could be stored.
  final SavedPhoto? saved;
  final PhotoNative native;

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

/// When to remind: two weeks before the photo gets too old, at 10:00.
DateTime reminderDateFor(DateTime expiry, DateTime now) {
  final early = DateTime(expiry.year, expiry.month, expiry.day - 14, 10);
  if (early.isAfter(now)) return early;
  return DateTime(expiry.year, expiry.month, expiry.day, 10);
}

class _DoneScreenState extends State<DoneScreen> {
  late SavedPhoto? _saved = widget.saved;
  bool _busy = false;

  void _home() => Navigator.of(context).popUntil((route) => route.isFirst);

  DateTime get _expiry =>
      expiryOf(_saved?.takenAt ?? DateTime.now(), widget.spec.validityMonths);

  Future<void> _toggleReminder(bool on) async {
    final saved = _saved;
    if (saved == null || _busy) return;
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final store = PhotoStoreScope.maybeOf(context);
    setState(() => _busy = true);
    try {
      if (on) {
        final at = reminderDateFor(_expiry, DateTime.now());
        final ok = await widget.native.scheduleReminder(
          id: 'photo-${saved.id}',
          at: at,
          title: l.remindTitle,
          body: l.remindBody(widget.spec.nameFor(lang), formatDate(_expiry, lang)),
        );
        if (!mounted) return;
        if (!ok) {
          showSnack(context, l.remindDenied);
          return;
        }
        showSnack(context, l.remindSet(formatDate(at, lang)));
      } else {
        await widget.native.cancelReminder('photo-${saved.id}');
      }
      final next = saved.copyWith(remind: on);
      await store?.update(next);
      if (mounted) setState(() => _saved = next);
    } on PhotoNativeUnavailable {
      if (mounted) showSnack(context, l.iosOnly);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final spec = widget.spec;
    final sheet = widget.sheetPath;
    final px = spec.pixelSize();
    final expired = DateTime.now().isAfter(_expiry);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _home,
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
                width: sheet == null ? 88 : 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x2E0F2A30), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Image.file(File(sheet ?? widget.photoPath), fit: BoxFit.fitWidth),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check, size: 18, color: AppColors.okText),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.savedToPhotos,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.okText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sheet == null ? l.digitalHowTitle : l.doneReady,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sheet == null
                          ? l.doneDigitalInfo(spec.nameFor(lang), px.width, px.height)
                          : l.doneSheetInfo(widget.paperLabel ?? '', widget.count, spec.nameFor(lang)),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (sheet != null) ...[
            Text(l.howToPrint, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const KonbiniSteps(),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.upload_file_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l.digitalHowBody, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: sheet != null
                    ? _ActionTile(
                        icon: Icons.download_outlined,
                        title: l.saveDigital,
                        subtitle: l.saveDigitalSub,
                        onTap: () async {
                          final ok = await widget.native.saveToPhotos(widget.photoPath);
                          if (context.mounted) showSnack(context, ok ? l.savedToPhotos : l.saveFailed);
                        },
                      )
                    : _ActionTile(
                        icon: Icons.storefront_outlined,
                        title: l.printSheetToo,
                        subtitle: l.paperL,
                        onTap: () => Navigator.of(context).pop(),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.ios_share,
                  title: l.shareLabel,
                  subtitle: l.shareSub,
                  onTap: () => widget.native.share(sheet ?? widget.photoPath),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available_outlined, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          expired
                              ? l.expiredLabel(spec.validityMonths)
                              : l.validUntil(formatDate(_expiry, lang)),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34, top: 2),
                    child: Text(
                      l.validMonthsNote(spec.validityMonths),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  if (_saved != null && !expired)
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.only(left: 34, right: 8),
                      title: Text(l.remindMe, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      value: _saved!.remind,
                      activeTrackColor: AppColors.primary,
                      onChanged: _busy ? null : _toggleReminder,
                    ),
                ],
              ),
            ),
          ),
          if (_saved != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(l.savedToMyPhotos, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActions(
        children: [
          OutlinedButton(onPressed: _home, child: Text(l.anotherDoc)),
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
