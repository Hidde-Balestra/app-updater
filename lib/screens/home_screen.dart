import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_library.dart';
import '../state/library_entry.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/section_header.dart';
import 'add_app_screen.dart';
import 'app_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppLibrary library;

  const HomeScreen({super.key, required this.library});

  Future<void> _scanDevice(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await library.syncInstalledVersions();
    final message = result.eligible == 0
        ? l10n.scanDeviceNoneEligible
        : result.removed > 0
        ? l10n.scanDeviceResultWithRemoved(
            result.updated,
            result.eligible,
            result.removed,
          )
        : l10n.scanDeviceResult(result.updated, result.eligible);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await library.downloadAndInstallAll();
    final total = result.succeeded + result.failed;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.updateAllResult(result.succeeded, total))),
    );
  }

  void _openDetail(BuildContext context, String appId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppDetailScreen(library: library, appId: appId),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddAppScreen(library: library)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: l10n.scanDeviceTooltip,
            onPressed: () => _scanDevice(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAdd(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          if (!library.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apps with an update available get their own section up top so
          // they're never buried below whatever else is tracked — the rest
          // of the sections below only show apps that are already current.
          // Within that section, the most neglected apps (installed longest
          // ago, or never installed at all) lead, so they get noticed first.
          final updatableApps =
              library.entries
                  .where((e) => e.status == AppCheckStatus.updateAvailable)
                  .toList()
                ..sort((a, b) {
                  final aTime = a.app.lastInstalledAt;
                  final bTime = b.app.lastInstalledAt;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return aTime.compareTo(bTime);
                });
          final myApps = library.entries
              .where(
                (e) =>
                    !e.app.isCurated &&
                    e.status != AppCheckStatus.updateAvailable,
              )
              .toList();
          final favoriteApps = library.entries
              .where(
                (e) =>
                    e.app.isCurated &&
                    e.status != AppCheckStatus.updateAvailable,
              )
              .toList();
          final isEmpty = library.entries.isEmpty;
          final updatableCount = updatableApps.length;

          return RefreshIndicator(
            onRefresh: library.checkAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (updatableCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _UpdateAllBanner(
                      count: updatableCount,
                      onUpdateAll: () => _updateAll(context),
                    ),
                  ),
                if (isEmpty)
                  _EmptyState(onAdd: () => _openAdd(context))
                else ...[
                  if (updatableApps.isNotEmpty) ...[
                    SectionHeader(title: l10n.sectionUpdatesAvailable),
                    for (final entry in updatableApps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppListTile(
                          entry: entry,
                          onTap: () => _openDetail(context, entry.app.id),
                        ),
                      ),
                  ],
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

class _UpdateAllBanner extends StatelessWidget {
  final int count;
  final VoidCallback onUpdateAll;

  const _UpdateAllBanner({required this.count, required this.onUpdateAll});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.updateAllBannerTitle(count),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onUpdateAll,
              child: Text(l10n.updateAllButton),
            ),
          ],
        ),
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
          Text(
            l10n.emptyLibraryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
