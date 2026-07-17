import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_source_type.dart';
import '../models/curated_app.dart';
import '../models/release_info.dart';
import '../models/tracked_app.dart';
import '../models/version_compare.dart';
import '../services/release_resolver.dart';
import 'library_entry.dart';

/// Owns the list of tracked apps (user-added + curated apps the user opted
/// into), the bundled list of curated suggestions, and drives release
/// checks against them. A plain ChangeNotifier, consistent with
/// [SettingsController] — no extra state-management package.
class AppLibrary extends ChangeNotifier {
  static const _kTrackedApps = 'library.trackedApps';

  final ReleaseResolver _resolver;

  AppLibrary({ReleaseResolver? resolver})
    : _resolver = resolver ?? ReleaseResolver();

  List<LibraryEntry> entries = [];
  List<CuratedApp> curatedApps = [];
  bool isLoaded = false;

  List<CuratedApp> get availableFavorites => curatedApps
      .where((c) => !entries.any((e) => e.app.isCurated && e.app.id == c.id))
      .toList();

  /// Loads curated apps and previously tracked apps, then kicks off a
  /// background release check for everything that's tracked.
  ///
  /// [curatedAppsOverride] skips the `rootBundle.loadString` asset read and
  /// is meant for widget tests: calling `rootBundle.loadString` from more
  /// than one `testWidgets` block in the same file has been observed to
  /// deadlock under `flutter test`'s concurrent multi-file execution (an
  /// asset-channel binding quirk between the two `TestWidgetsFlutterBinding`
  /// resets, not an app bug — plain `test()` cases and single-file runs are
  /// unaffected). Only [AppLibrary]'s own asset-loading test exercises the
  /// real path.
  Future<void> load({List<CuratedApp>? curatedAppsOverride}) async {
    curatedApps = curatedAppsOverride ?? await _loadCuratedApps();
    entries = await _loadTrackedApps();
    isLoaded = true;
    notifyListeners();
    unawaited(checkAll());
  }

  Future<List<CuratedApp>> _loadCuratedApps() async {
    final raw = await rootBundle.loadString('assets/curated_apps.json');
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(CuratedApp.fromJson)
        .toList(growable: false);
  }

  Future<List<LibraryEntry>> _loadTrackedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTrackedApps);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(TrackedApp.fromJson)
        .map((app) => LibraryEntry(app: app, status: AppCheckStatus.checking))
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.app.toJson()).toList());
    await prefs.setString(_kTrackedApps, raw);
  }

  Future<ReleaseResult> previewSource(AppSourceType type, String source) {
    return _resolver.resolve(type, source);
  }

  Future<TrackedApp> addCustomApp({
    required String name,
    required AppSourceType type,
    required String source,
  }) async {
    final app = TrackedApp(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      sourceType: type,
      sourceIdentifier: source,
    );
    entries = [
      ...entries,
      LibraryEntry(app: app, status: AppCheckStatus.checking),
    ];
    notifyListeners();
    await _persist();
    await checkOne(app.id);
    return app;
  }

  Future<void> addFavorite(CuratedApp curated) async {
    if (entries.any((e) => e.app.id == curated.id)) return;
    final app = TrackedApp(
      id: curated.id,
      name: curated.name,
      sourceType: curated.sourceType,
      sourceIdentifier: curated.sourceIdentifier,
      isCurated: true,
    );
    entries = [
      ...entries,
      LibraryEntry(app: app, status: AppCheckStatus.checking),
    ];
    notifyListeners();
    await _persist();
    await checkOne(app.id);
  }

  Future<void> removeApp(String id) async {
    entries = entries.where((e) => e.app.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> markInstalled(String id, String version) async {
    entries = [
      for (final e in entries)
        if (e.app.id == id)
          e.copyWith(
            app: e.app.copyWith(installedVersion: version),
            status: AppCheckStatus.upToDate,
          )
        else
          e,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> checkAll() async {
    await Future.wait(entries.map((e) => checkOne(e.app.id)));
  }

  Future<void> checkOne(String id) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    final entry = entries[index];

    _updateEntry(id, (e) => e.copyWith(status: AppCheckStatus.checking));

    final result = await _resolver.resolve(
      entry.app.sourceType,
      entry.app.sourceIdentifier,
    );

    switch (result) {
      case ReleaseSuccess(:final info):
        final status = _statusFor(entry.app, info);
        _updateEntry(
          id,
          (e) => e.copyWith(
            status: status,
            latestRelease: info,
            errorMessage: null,
          ),
        );
      case ReleaseNotFound():
        _updateEntry(id, (e) => e.copyWith(status: AppCheckStatus.noReleases));
      case ReleaseError(:final message):
        _updateEntry(
          id,
          (e) =>
              e.copyWith(status: AppCheckStatus.error, errorMessage: message),
        );
    }
  }

  AppCheckStatus _statusFor(TrackedApp app, ReleaseInfo info) {
    if (app.sourceType == AppSourceType.direct) {
      return app.installedVersion == null
          ? AppCheckStatus.updateAvailable
          : AppCheckStatus.upToDate;
    }
    final hasUpdate = isUpdateAvailable(
      installedVersion: app.installedVersion,
      latestVersion: info.version,
    );
    return hasUpdate ? AppCheckStatus.updateAvailable : AppCheckStatus.upToDate;
  }

  void _updateEntry(String id, LibraryEntry Function(LibraryEntry) update) {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    final updated = [...entries];
    updated[index] = update(updated[index]);
    entries = updated;
    notifyListeners();
  }
}
