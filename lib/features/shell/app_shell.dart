import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/specs/photo_spec.dart';
import '../../core/specs/spec_repository.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart';
import '../photos/photos_screen.dart';
import '../print_guide/print_guide_screen.dart';

/// Home, My photos and How to print, behind a bottom bar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.specRepository,
    required this.localeController,
  });

  final SpecRepository specRepository;
  final LocaleController localeController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  late final Future<List<PhotoSpec>> _specs = widget.specRepository.load();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            specRepository: widget.specRepository,
            localeController: widget.localeController,
            onOpenPhotos: () => setState(() => _tab = 1),
          ),
          FutureBuilder<List<PhotoSpec>>(
            future: _specs,
            builder: (context, snap) => snap.hasData
                ? PhotosScreen(specs: snap.data!)
                : const Center(child: CircularProgressIndicator()),
          ),
          const PrintGuideScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l.navHome),
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: l.navPhotos,
          ),
          NavigationDestination(icon: const Icon(Icons.print_outlined), selectedIcon: const Icon(Icons.print), label: l.navPrint),
        ],
      ),
    );
  }
}
