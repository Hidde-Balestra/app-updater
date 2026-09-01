import 'package:flutter/material.dart';

import '../models/changelog_line.dart';
import '../state/library_entry.dart';
import 'app_avatar.dart';
import 'status_chip.dart';

class AppListTile extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onTap;

  const AppListTile({super.key, required this.entry, required this.onTap});

  String _versionLabel() {
    final installed = entry.app.installedVersion;
    final latest = entry.latestRelease?.version;
    if (latest == null || latest.isEmpty) {
      return installed ?? '—';
    }
    if (installed == null) return latest;
    if (installed == latest) return installed;
    return '$installed → $latest';
  }

  /// The first non-header changelog line, for a one-line preview under an
  /// updatable app's version label — the full changelog stays a tap away on
  /// the detail screen. Header lines (e.g. a "## v2.0.0" repeating the
  /// version already shown above it) are skipped so the preview always
  /// shows actual content.
  String? _changelogPreview() {
    if (entry.status != AppCheckStatus.updateAvailable) return null;
    final contentLines = parseChangelog(
      entry.latestRelease?.changelog,
    ).where((l) => l.kind != ChangelogLineKind.header);
    return contentLines.isEmpty ? null : contentLines.first.text;
  }

  @override
  Widget build(BuildContext context) {
    final changelogPreview = _changelogPreview();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppAvatar(name: entry.app.name, initials: entry.app.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.app.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _versionLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (changelogPreview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        changelogPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: entry.status),
            ],
          ),
        ),
      ),
    );
  }
}
