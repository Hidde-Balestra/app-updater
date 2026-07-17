import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_library.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/section_header.dart';
import 'add_app_screen.dart';
import 'app_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppLibrary library;

  const HomeScreen({super.key, required this.library});

  void _openDetail(BuildContext context, String appId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AppDetailScreen(library: library, appId: appId)));
  }

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddAppScreen(library: library)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openAdd(context)),
        ],
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          if (!library.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final myApps = library.entries.where((e) => !e.app.isCurated).toList();
          final favoriteApps = library.entries.where((e) => e.app.isCurated).toList();
          final isEmpty = myApps.isEmpty && favoriteApps.isEmpty;

          return RefreshIndicator(
            onRefresh: library.checkAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isEmpty)
                  _EmptyState(onAdd: () => _openAdd(context))
                else ...[
                  if (myApps.isNotEmpty) ...[
                    SectionHeader(title: l10n.sectionMyApps),
                    for (final entry in myApps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppListTile(
                          entry: entry,
                          onTap: () => _openDetail(context, entry.app.id),
                        ),
                      ),
                  ],
                  if (favoriteApps.isNotEmpty) ...[
                    SectionHeader(title: l10n.sectionFavoriteApps),
                    for (final entry in favoriteApps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppListTile(
                          entry: entry,
                          onTap: () => _openDetail(context, entry.app.id),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Column(
        children: [
          Icon(
            Icons.apps_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(l10n.emptyLibraryTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.emptyLibraryMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addAppButton),
          ),
        ],
      ),
    );
  }
}
