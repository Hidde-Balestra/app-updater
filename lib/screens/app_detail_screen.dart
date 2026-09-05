import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/app_source_type.dart';
import '../models/changelog_line.dart';
import '../state/app_library.dart';
import '../state/library_entry.dart';
import '../widgets/app_avatar.dart';
import '../widgets/status_chip.dart';

class AppDetailScreen extends StatefulWidget {
  final AppLibrary library;
  final String appId;

  const AppDetailScreen({
    super.key,
    required this.library,
    required this.appId,
  });

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  bool _isDownloading = false;
  double _progress = 0;

  String _humanSize(int? bytes) {
    if (bytes == null) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _downloadAndInstall(LibraryEntry entry) async {
    if (entry.latestRelease == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });
    try {
      await widget.library.downloadAndInstall(
        entry.app.id,
        onProgress: (received, total) {
          if (total != null && total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
        confirmSigningMismatch: _confirmSigningMismatch,
      );
    } on SigningMismatchException {
      // The user already saw and declined the warning in
      // _confirmSigningMismatch — nothing more to show.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<bool> _confirmSigningMismatch() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signingMismatchTitle),
        content: Text(l10n.signingMismatchMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.installAnywayButton,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _copySha256(String hash) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: hash));
    messenger.showSnackBar(SnackBar(content: Text(l10n.sha256Copied)));
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _skipVersion(LibraryEntry entry) async {
    final release = entry.latestRelease;
    if (release == null) return;
    await widget.library.skipVersion(entry.app.id, release.version);
  }

  Future<void> _unskipVersion(LibraryEntry entry) async {
    await widget.library.unskipVersion(entry.app.id);
  }

  Future<void> _confirmRemove(LibraryEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAppConfirmTitle),
        content: Text(l10n.removeAppConfirmMessage(entry.app.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.remove,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.library.removeApp(entry.app.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        final entry = widget.library.entries
            .where((e) => e.app.id == widget.appId)
            .firstOrNull;
        if (entry == null) {
          return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
        }

        final release = entry.latestRelease;
        final hasUpdate = entry.status == AppCheckStatus.updateAvailable;
        final isSkipped = entry.status == AppCheckStatus.skipped;
        final isAccrescent = entry.app.sourceType == AppSourceType.accrescent;
        final changelogLines = parseChangelog(release?.changelog);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.detailsTitle),
            actions: [
              StatusChip(status: entry.status),
              const SizedBox(width: 12),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  AppAvatar(
                    name: entry.app.name,
                    initials: entry.app.initials,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.app.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          entry.app.sourceIdentifier,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (hasUpdate && release != null)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.updateAvailableBanner(
                        entry.app.installedVersion ?? '—',
                        release.version.isEmpty ? '—' : release.version,
                        _humanSize(release.sizeBytes),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (isSkipped && release != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.skippedVersionBanner(release.version),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unskipVersion(entry),
                          child: Text(l10n.unskipVersionButton),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (release != null && isAccrescent) ...[
                FilledButton.icon(
                  onPressed: () => _openSource(release.downloadUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.openInAccrescentButton),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.accrescentNoDirectDownload,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (release != null)
                FilledButton.icon(
                  onPressed: _isDownloading
                      ? null
                      : () => _downloadAndInstall(entry),
                  icon: _isDownloading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    _isDownloading
                        ? l10n.downloadingButton((_progress * 100).round())
                        : l10n.downloadInstallButton,
                  ),
                ),
              if (hasUpdate && release != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _skipVersion(entry),
                    child: Text(l10n.skipVersionButton),
                  ),
                ),
              ],
              if (entry.lastDownloadSha256 != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _copySha256(entry.lastDownloadSha256!),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.sha256Label(entry.lastDownloadSha256!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                        ),
                      ),
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
              if (changelogLines.isNotEmpty && release != null) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.changesInVersion(
                    release.version.isEmpty ? '—' : release.version,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...changelogLines.map(
                  (line) => Padding(
                    padding: EdgeInsets.only(
                      top: line.startsNewBlock ? 10 : 0,
                      bottom: 4,
                    ),
                    child: switch (line.kind) {
                      ChangelogLineKind.header => Text(
                        line.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ChangelogLineKind.bullet => Text('•  ${line.text}'),
                      ChangelogLineKind.paragraph => Text(line.text),
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              InkWell(
                onTap: () => _openSource(
                  release?.sourcePageUrl ?? entry.app.sourceLabel,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.sourceLabelDetail(entry.app.sourceLabel),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.lastCheckedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.lastCheckedLabel(
                    DateFormat(
                      'd MMM yyyy, HH:mm',
                    ).format(entry.lastCheckedAt!),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _confirmRemove(entry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                child: Text(l10n.removeAppButton),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
