import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_source_type.dart';
import '../models/curated_app.dart';
import '../models/installed_app.dart';
import '../models/release_info.dart';
import '../models/source_parser.dart';
import '../state/app_library.dart';
import '../widgets/app_avatar.dart';

typedef _DeviceAppsPage = ({
  List<InstalledApp> apps,
  Set<String> fdroidAvailable,
});

class AddAppScreen extends StatefulWidget {
  final AppLibrary library;

  /// When set, prefills the custom-app tab's name and package name fields
  /// on open — used when navigating here from the device-apps overview in
  /// Settings, so the user only has to pick a source.
  final InstalledApp? prefillApp;

  const AddAppScreen({super.key, required this.library, this.prefillApp});

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _sourceController = TextEditingController();
  final _nameController = TextEditingController();
  final _packageNameController = TextEditingController();

  AppSourceType _sourceType = AppSourceType.github;
  Timer? _debounce;
  String? _resolvedIdentifier;
  ReleaseResult? _previewResult;
  bool _isChecking = false;
  bool _isSaving = false;

  Future<_DeviceAppsPage>? _deviceAppsFuture;
  bool _isBulkAddingFdroid = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _sourceController.addListener(_onSourceChanged);
    _loadInstalledApps();
    final prefill = widget.prefillApp;
    if (prefill != null) {
      _prefillFromInstalledApp(prefill);
    }
  }

  void _loadInstalledApps() {
    setState(() {
      _deviceAppsFuture = _loadDeviceAppsPage();
    });
  }

  Future<_DeviceAppsPage> _loadDeviceAppsPage() async {
    final apps = await widget.library.installedAppsNotTracked();
    final fdroidAvailable = await widget.library.findFdroidAvailable(apps);
    return (apps: apps, fdroidAvailable: fdroidAvailable);
  }

  Future<void> _addAllFdroidApps(_DeviceAppsPage page) async {
    final targets = page.apps
        .where((app) => page.fdroidAvailable.contains(app.packageName))
        .toList();
    if (targets.isEmpty) return;

    setState(() => _isBulkAddingFdroid = true);
    for (final app in targets) {
      await widget.library.addCustomApp(
        name: app.name,
        type: AppSourceType.fdroid,
        source: app.packageName,
        packageName: app.packageName,
      );
    }
    if (!mounted) return;
    setState(() => _isBulkAddingFdroid = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.addAllFdroidResult(targets.length),
        ),
      ),
    );
    _loadInstalledApps();
  }

  /// Fills in the name/package fields for [app] and tries F-Droid as the
  /// source, keyed by the exact package name — F-Droid indexes apps by
  /// their Android application id, so this is a reliable auto-match when
  /// the app happens to be on F-Droid, unlike GitHub/GitLab/Codeberg where
  /// there's no equivalent exact lookup (only a fuzzy name search, which
  /// risks matching the wrong project). Setting `_sourceController.text`
  /// feeds the existing debounced preview pipeline, so if F-Droid doesn't
  /// have it, this just shows the normal "not found" state and the user
  /// can switch source type and enter it by hand.
  void _prefillFromInstalledApp(InstalledApp app) {
    _nameController.text = app.name;
    _packageNameController.text = app.packageName;
    _sourceType = AppSourceType.fdroid;
    _previewResult = null;
    _resolvedIdentifier = null;
    _sourceController.text = app.packageName;
  }

  void _useInstalledApp(InstalledApp app) {
    setState(() => _prefillFromInstalledApp(app));
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.useInstalledAppHint(app.name),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sourceController.dispose();
    _nameController.dispose();
    _packageNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    _debounce?.cancel();
    final text = _sourceController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _previewResult = null;
        _resolvedIdentifier = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _resolvePreview(text),
    );
  }

  Future<void> _resolvePreview(String rawInput) async {
    final identifier = switch (_sourceType) {
      AppSourceType.github => parseGithubSource(rawInput),
      AppSourceType.gitlab => parseGitlabSource(rawInput),
      AppSourceType.codeberg => parseCodebergSource(rawInput),
      AppSourceType.fdroid => parseFdroidSource(rawInput),
      AppSourceType.direct => rawInput.trim(),
    };
    if (identifier == null || identifier.isEmpty) {
      setState(() {
        _previewResult = const ReleaseError('invalid_source');
        _resolvedIdentifier = null;
      });
      return;
    }

    setState(() => _isChecking = true);
    final result = await widget.library.previewSource(_sourceType, identifier);
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _resolvedIdentifier = identifier;
      _previewResult = result;
    });
  }

  Future<void> _addCustomApp() async {
    final identifier = _resolvedIdentifier;
    if (identifier == null || _previewResult is! ReleaseSuccess) return;

    setState(() => _isSaving = true);
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : defaultNameFor(
            identifierKind: _sourceType.name,
            identifier: identifier,
          );

    await widget.library.addCustomApp(
      name: displayName,
      type: _sourceType,
      source: identifier,
      packageName: _packageNameController.text.trim().isNotEmpty
          ? _packageNameController.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    _sourceController.clear();
    _nameController.clear();
    _packageNameController.clear();
    setState(() {
      _previewResult = null;
      _resolvedIdentifier = null;
    });
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addAppTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.tabCustomApp),
            Tab(text: l10n.tabFavorite),
            Tab(text: l10n.tabDeviceApps),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCustomAppTab(l10n),
          _buildFavoriteTab(l10n),
          _buildDeviceAppsTab(l10n),
        ],
      ),
    );
  }

  Widget _buildCustomAppTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.sourceLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<AppSourceType>(
            segments: [
              ButtonSegment(
                value: AppSourceType.github,
                label: Text(l10n.sourceTypeGithub),
              ),
              ButtonSegment(
                value: AppSourceType.gitlab,
                label: Text(l10n.sourceTypeGitlab),
              ),
              ButtonSegment(
                value: AppSourceType.codeberg,
                label: Text(l10n.sourceTypeCodeberg),
              ),
              ButtonSegment(
                value: AppSourceType.fdroid,
                label: Text(l10n.sourceTypeFdroid),
              ),
              ButtonSegment(
                value: AppSourceType.direct,
                label: Text(l10n.sourceTypeDirect),
              ),
            ],
            selected: {_sourceType},
            onSelectionChanged: (selection) {
              setState(() => _sourceType = selection.first);
              if (_sourceController.text.trim().isNotEmpty) {
                _resolvePreview(_sourceController.text);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sourceController,
          decoration: InputDecoration(hintText: l10n.sourceFieldHint),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.displayNameLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: l10n.displayNameHint),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.packageNameLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _packageNameController,
          decoration: InputDecoration(hintText: l10n.packageNameHint),
        ),
        const SizedBox(height: 20),
        _buildPreviewCard(l10n),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (_previewResult is ReleaseSuccess && !_isSaving)
              ? _addCustomApp
              : null,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.addAppButton),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(AppLocalizations l10n) {
    if (_isChecking) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final result = _previewResult;
    if (result == null) return const SizedBox.shrink();

    return switch (result) {
      ReleaseSuccess(:final info) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppAvatar(
                name: _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : (_resolvedIdentifier ?? '?'),
                initials: _previewInitials(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : defaultNameFor(
                              identifierKind: _sourceType.name,
                              identifier: _resolvedIdentifier ?? '',
                            ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _resolvedIdentifier ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.latestReleaseFound(
                        info.version.isEmpty ? '—' : info.version,
                        _sourceTypeLabel(l10n),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ReleaseNotFound() => _MessageCard(message: l10n.sourceResolveError),
      ReleaseError() => _MessageCard(message: l10n.invalidSourceError),
    };
  }

  String _sourceTypeLabel(AppLocalizations l10n) => switch (_sourceType) {
    AppSourceType.github => l10n.sourceTypeGithub,
    AppSourceType.gitlab => l10n.sourceTypeGitlab,
    AppSourceType.codeberg => l10n.sourceTypeCodeberg,
    AppSourceType.fdroid => l10n.sourceTypeFdroid,
    AppSourceType.direct => l10n.sourceTypeDirect,
  };

  String _previewInitials() {
    final source = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : defaultNameFor(
            identifierKind: _sourceType.name,
            identifier: _resolvedIdentifier ?? '?',
          );
    final words = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Widget _buildFavoriteTab(AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        final favorites = widget.library.availableFavorites;
        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.favoritesEmptyAllAdded,
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
          itemCount: favorites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _FavoriteTile(app: favorites[index], library: widget.library),
        );
      },
    );
  }

  Widget _buildDeviceAppsTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: () async => _loadInstalledApps(),
      child: FutureBuilder<_DeviceAppsPage>(
        future: _deviceAppsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final apps = snapshot.data?.apps ?? const <InstalledApp>[];
          final fdroidAvailable =
              snapshot.data?.fdroidAvailable ?? const <String>{};
          if (apps.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.deviceAppsEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          }
          final showBanner = fdroidAvailable.isNotEmpty;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length + (showBanner ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (showBanner && index == 0) {
                return _AddAllFdroidBanner(
                  count: fdroidAvailable.length,
                  isBusy: _isBulkAddingFdroid,
                  onPressed: () => _addAllFdroidApps((
                    apps: apps,
                    fdroidAvailable: fdroidAvailable,
                  )),
                );
              }
              final app = apps[showBanner ? index - 1 : index];
              return _DeviceAppTile(
                app: app,
                onUse: () => _useInstalledApp(app),
                isFdroidAvailable: fdroidAvailable.contains(app.packageName),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final CuratedApp app;
  final AppLibrary library;

  const _FavoriteTile({required this.app, required this.library});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    app.sourceIdentifier,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => library.addFavorite(app),
              child: Text(l10n.addFavoriteButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAllFdroidBanner extends StatelessWidget {
  final int count;
  final bool isBusy;
  final VoidCallback onPressed;

  const _AddAllFdroidBanner({
    required this.count,
    required this.isBusy,
    required this.onPressed,
  });

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
                l10n.addAllFdroidBannerTitle(count),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: isBusy ? null : onPressed,
              child: isBusy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.addAllFdroidButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceAppTile extends StatelessWidget {
  final InstalledApp app;
  final VoidCallback onUse;
  final bool isFdroidAvailable;

  const _DeviceAppTile({
    required this.app,
    required this.onUse,
    this.isFdroidAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isFdroidAvailable) ...[
                        const SizedBox(width: 6),
                        _SourceBadge(label: l10n.sourceTypeFdroid),
                      ],
                    ],
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
            FilledButton.tonal(
              onPressed: onUse,
              child: Text(l10n.useInstalledAppButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;

  const _SourceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
