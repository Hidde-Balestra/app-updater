import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/update_history_entry.dart';
import '../state/app_library.dart';
import '../widgets/app_avatar.dart';

/// A local log of every download-and-install performed through this app,
/// most recent first — reachable from Settings, for answering "did this
/// actually update last week?" without digging through Android's own
/// install log.
class UpdateHistoryScreen extends StatelessWidget {
  final AppLibrary library;

  const UpdateHistoryScreen({super.key, required this.library});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.updateHistoryMenuTitle)),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final history = library.updateHistory;
          if (history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.updateHistoryEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _HistoryTile(entry: history[index]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final UpdateHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initials = entry.appName.length >= 2
        ? entry.appName.substring(0, 2).toUpperCase()
        : entry.appName.toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AppAvatar(name: entry.appName, initials: initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.appName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.updateHistoryEntryVersions(
                      entry.fromVersion ?? '—',
                      entry.toVersion,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('d MMM yyyy, HH:mm').format(entry.installedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
