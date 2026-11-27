import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/specs/spec_repository.dart';
import '../../core/store/photo_store.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/photo_native.dart';
import '../../widgets/document_picker.dart';
import '../../widgets/flow_widgets.dart';
import '../capture/face_analyzer.dart';
import '../review/review_screen.dart';
import '../photos/photos_screen.dart';
import '../prepare/prepare_screen.dart';
import '../settings/settings_screen.dart';
import '../spec_detail/spec_detail_screen.dart';

/// Start: one big "take ID photo" action for the chosen document, then the
/// list of documents with their rules.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.specRepository,
    required this.localeController,
    this.onOpenPhotos,
    this.native = const PhotoNative(),
  });

  final SpecRepository specRepository;
  final LocaleController localeController;

  /// Switches to the My photos tab.
  final VoidCallback? onOpenPhotos;
  final PhotoNative native;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<PhotoSpec>> _specs = widget.specRepository.load();
  String _query = '';
  String? _selectedId;

  PhotoSpec _selected(List<PhotoSpec> specs) =>
      specs.where((s) => s.id == _selectedId).firstOrNull ??
      specs.where((s) => !s.pro).firstOrNull ??
      specs.first;

  void _openCapture(PhotoSpec spec) {
    setState(() => _selectedId = spec.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PrepareScreen(spec: spec)),
    );
  }

  void _openDetail(PhotoSpec spec) {
    setState(() => _selectedId = spec.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SpecDetailScreen(spec: spec)),
    );
  }

  Future<void> _pickPhoto(PhotoSpec spec) async {
    final l = AppLocalizations.of(context);
    try {
      final path = await widget.native.pickPhoto();
      if (path == null || !mounted) return;
      final analyzer = FaceAnalyzer();
      final metrics = await analyzer.analyzeFile(path);
      await analyzer.close();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewScreen(spec: spec, shots: [path], metrics: [metrics]),
        ),
      );
    } on PhotoNativeUnavailable {
      if (mounted) showSnack(context, l.iosOnly);
    }
  }

  Future<void> _chooseDocument(List<PhotoSpec> specs) async {
    final picked = await showDocumentPicker(context, specs, selectedId: _selected(specs).id);
    if (picked != null) setState(() => _selectedId = picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.portrait_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(l.appTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(localeController: widget.localeController),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<PhotoSpec>>(
        future: _specs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final selected = _selected(all);
          final q = _query.trim().toLowerCase();
          final specs = all
              .where(
                (s) =>
                    q.isEmpty ||
                    s.nameFor(lang).toLowerCase().contains(q) ||
                    s.jaName.contains(_query.trim()),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _Hero(
                docName: selected.nameFor(lang),
                onTake: () => _openCapture(selected),
                onPick: () => _pickPhoto(selected),
                onChangeDoc: () => _chooseDocument(all),
              ),
              _RecentPhotos(specs: all, onSeeAll: widget.onOpenPhotos),
              const SizedBox(height: 22),
              Text(
                l.homeHeadline,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SearchBar(
                hintText: l.searchHint,
                leading: const Icon(Icons.search, size: 20),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(Colors.white),
                side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
                constraints: const BoxConstraints(minHeight: 46),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (specs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(child: Text(l.noResults)),
                ),
              for (final spec in specs) ...[
                _SpecCard(
                  spec: spec,
                  lang: lang,
                  selected: spec.id == selected.id,
                  onTap: () => _openDetail(spec),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The latest saved photos, so reprinting is one tap from home.
class _RecentPhotos extends StatelessWidget {
  const _RecentPhotos({required this.specs, this.onSeeAll});

  final List<PhotoSpec> specs;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = PhotoStoreScope.maybeOf(context);
    if (store == null) return const SizedBox.shrink();
    final actions = SavedPhotoActions(context, specs);
    final recent = store.items.where((p) => actions.specOf(p) != null).take(2).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: store.folder(),
      builder: (context, snap) {
        final dir = snap.data;
        if (dir == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(l.navPhotos, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: Text(l.seeAll)),
              ],
            ),
            for (final p in recent) ...[
              SavedPhotoCard(
                photo: p,
                spec: actions.specOf(p)!,
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
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.docName,
    required this.onTake,
    required this.onPick,
    required this.onChangeDoc,
  });

  final String docName;
  final VoidCallback onTake;
  final VoidCallback onPick;
  final VoidCallback onChangeDoc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.heroTitle,
            style: const TextStyle(color: Colors.white, fontSize: 21, height: 1.3, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            l.heroBody,
            style: const TextStyle(color: AppColors.onPrimaryMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l.ctaTakePhoto),
                  onPressed: onTake,
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: l.ctaPickPhoto,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF4F8E99)),
                  ),
                  onPressed: onPick,
                  child: Icon(Icons.photo_library_outlined, semanticLabel: l.ctaPickPhoto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              l.ctaForDoc(docName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: onChangeDoc,
          ),
        ],
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({
    required this.spec,
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final PhotoSpec spec;
  final String lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final showJa = lang != 'ja';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _SizePreview(spec: spec),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spec.nameFor(lang),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (showJa) ...[
                      const SizedBox(height: 2),
                      Text(
                        spec.jaName,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          l.sizeValue(formatMm(spec.heightMm), formatMm(spec.widthMm)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                        ),
                        if (!spec.verified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small to-scale outline of the photo, so sizes are compared by eye.
class _SizePreview extends StatelessWidget {
  const _SizePreview({required this.spec});

  final PhotoSpec spec;

  static const _boxPx = 52.0;
  static const _maxMm = 60.0;

  @override
  Widget build(BuildContext context) {
    const scale = _boxPx / _maxMm;
    return Container(
      width: _boxPx,
      height: _boxPx,
      decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Container(
        width: spec.widthMm * scale,
        height: spec.heightMm * scale,
        decoration: BoxDecoration(
          color: spec.backgrounds.first.swatch,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF9DB3B6)),
        ),
        child: Icon(
          specIcon(spec.icon),
          size: spec.widthMm * scale * 0.6,
          color: AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
