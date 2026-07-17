import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_source_type.dart';
import '../models/curated_app.dart';
import '../models/release_info.dart';
import '../models/source_parser.dart';
import '../state/app_library.dart';
import '../widgets/app_avatar.dart';

class AddAppScreen extends StatefulWidget {
  final AppLibrary library;

  const AddAppScreen({super.key, required this.library});

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _sourceController = TextEditingController();
  final _nameController = TextEditingController();

  AppSourceType _sourceType = AppSourceType.github;
  Timer? _debounce;
  String? _resolvedIdentifier;
  ReleaseResult? _previewResult;
  bool _isChecking = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sourceController.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sourceController.dispose();
    _nameController.dispose();
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
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    _sourceController.clear();
    _nameController.clear();
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCustomAppTab(l10n), _buildFavoriteTab(l10n)],
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
        SegmentedButton<AppSourceType>(
          segments: [
            ButtonSegment(
              value: AppSourceType.github,
              label: Text(l10n.sourceTypeGithub),
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
