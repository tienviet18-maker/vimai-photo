import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/spec_l10n.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/specs/spec_repository.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart';
import '../spec_detail/spec_detail_screen.dart';

/// Step 1 of 3: the user picks the document, not a size.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.specRepository,
    required this.localeController,
  });

  final SpecRepository specRepository;
  final LocaleController localeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<PhotoSpec>> _specs = widget.specRepository.load();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SettingsScreen(localeController: widget.localeController),
              ),
            ),
          ),
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
          final q = _query.trim().toLowerCase();
          final specs = snapshot.data!
              .where(
                (s) =>
                    q.isEmpty ||
                    s.nameFor(lang).toLowerCase().contains(q) ||
                    s.jaName.contains(_query.trim()),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(l.homeHeadline, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                l.homeSubline,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SearchBar(
                hintText: l.searchHint,
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 16),
              if (specs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(child: Text(l.noResults)),
                ),
              for (final spec in specs) ...[
                _SpecCard(spec: spec, lang: lang),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.spec, required this.lang});

  final PhotoSpec spec;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showJa = lang != 'ja';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SpecDetailScreen(spec: spec)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _SizePreview(spec: spec),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(specIcon(spec.icon), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spec.nameFor(lang),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (spec.pro) _ProBadge(label: l.proBadge),
                      ],
                    ),
                    if (showJa) ...[
                      const SizedBox(height: 2),
                      Text(
                        spec.jaName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      l.sizeValue(
                        formatMm(spec.heightMm),
                        formatMm(spec.widthMm),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (!spec.verified)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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

  static const _boxPx = 56.0;
  static const _maxMm = 60.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = _boxPx / _maxMm;
    return SizedBox.square(
      dimension: _boxPx,
      child: Center(
        child: Container(
          width: spec.widthMm * scale,
          height: spec.heightMm * scale,
          decoration: BoxDecoration(
            color: spec.backgrounds.first.swatch,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: scheme.outline),
          ),
          child: Icon(
            Icons.person,
            size: spec.widthMm * scale * 0.8,
            color: scheme.primary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onTertiaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
