import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/apk_installer_service.dart';
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
  final _installer = ApkInstallerService();
  bool _isDownloading = false;
  double _progress = 0;

  String _humanSize(int? bytes) {
    if (bytes == null) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _downloadAndInstall(LibraryEntry entry) async {
    final release = entry.latestRelease;
    if (release == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });
    try {
      final safeVersion = release.version.isEmpty ? 'latest' : release.version;
      final fileName = '${entry.app.id}-$safeVersion.apk';
      final path = await _installer.downloadApk(
        url: release.downloadUrl,
        fileName: fileName,
        onProgress: (received, total) {
          if (total != null && total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      await _installer.installApk(path);
      if (!mounted) return;
      final installedVersion = release.version.isEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : release.version;
      await widget.library.markInstalled(entry.app.id, installedVersion);
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

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        final changelogLines = (release?.changelog ?? '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

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
              const SizedBox(height: 16),
              if (release != null)
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
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  $line'),
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
