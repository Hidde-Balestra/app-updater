import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/device_app_entry.dart';
import '../models/installed_app.dart';
import '../state/app_library.dart';
import '../widgets/app_avatar.dart';
import 'add_app_screen.dart';

/// Combined overview of every app installed on the device — already
/// tracked, ignored, or available to add — reachable from Settings rather
/// than only from the add-app flow, so it works as a standalone "what's on
/// my phone" screen too.
class DeviceAppsScreen extends StatefulWidget {
  final AppLibrary library;

  const DeviceAppsScreen({super.key, required this.library});

  @override
  State<DeviceAppsScreen> createState() => _DeviceAppsScreenState();
}

class _DeviceAppsScreenState extends State<DeviceAppsScreen> {
  bool _isLoading = true;
  List<DeviceAppEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final entries = await widget.library.deviceAppOverview();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  void _updateStatus(String packageName, DeviceAppStatus status) {
    setState(() {
      _entries = [
        for (final entry in _entries)
          if (entry.app.packageName == packageName)
            DeviceAppEntry(app: entry.app, status: status)
          else
            entry,
      ];
    });
  }

  Future<void> _ignore(InstalledApp app) async {
    await widget.library.ignorePackage(app.packageName);
    _updateStatus(app.packageName, DeviceAppStatus.ignored);
  }

  Future<void> _unignore(InstalledApp app) async {
    await widget.library.unignorePackage(app.packageName);
    _updateStatus(app.packageName, DeviceAppStatus.available);
  }

  void _use(InstalledApp app) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddAppScreen(library: widget.library, prefillApp: app),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceAppsScreenTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.deviceAppsScreenEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _DeviceOverviewTile(
                    entry: entry,
                    onUse: () => _use(entry.app),
                    onIgnore: () => _ignore(entry.app),
                    onUnignore: () => _unignore(entry.app),
                  );
                },
              ),
      ),
    );
  }
}

class _DeviceOverviewTile extends StatelessWidget {
  final DeviceAppEntry entry;
  final VoidCallback onUse;
  final VoidCallback onIgnore;
  final VoidCallback onUnignore;

  const _DeviceOverviewTile({
    required this.entry,
    required this.onUse,
    required this.onIgnore,
    required this.onUnignore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = entry.app;
    final initials = app.name.length >= 2
        ? app.name.substring(0, 2).toUpperCase()
        : app.name.toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AppAvatar(name: app.name, initials: initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    app.packageName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ...switch (entry.status) {
              DeviceAppStatus.tracked => [
                Text(
                  l10n.deviceStatusTracked,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              DeviceAppStatus.ignored => [
                Text(
                  l10n.deviceStatusIgnored,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: onUnignore,
                  child: Text(l10n.unignoreButton),
                ),
              ],
              DeviceAppStatus.available => [
                TextButton(onPressed: onIgnore, child: Text(l10n.ignoreButton)),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: onUse,
                  child: Text(l10n.useInstalledAppButton),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}
