import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_source_type.dart';
import '../models/curated_app.dart';
import '../models/device_app_entry.dart';
import '../models/installed_app.dart';
import '../models/release_info.dart';
import '../models/tracked_app.dart';
import '../models/update_history_entry.dart';
import '../models/version_compare.dart';
import '../services/apk_installer_service.dart';
import '../services/device_apps_service.dart';
import '../services/release_resolver.dart';
import 'library_entry.dart';
import 'storage_keys.dart';

/// Owns the list of tracked apps (user-added + curated apps the user opted
/// into), the bundled list of curated suggestions, and drives release
/// checks against them. A plain ChangeNotifier, consistent with
/// [SettingsController] — no extra state-management package.
class AppLibrary extends ChangeNotifier {
  static const _kTrackedApps = StorageKeys.trackedApps;

  final ReleaseResolver _resolver;
  final DeviceAppsService _deviceApps;
  final ApkInstallerService _installer;

  AppLibrary({
    ReleaseResolver? resolver,
    DeviceAppsService? deviceApps,
    ApkInstallerService? installer,
  }) : _resolver = resolver ?? ReleaseResolver(),
       _deviceApps = deviceApps ?? DeviceAppsService(),
       _installer = installer ?? ApkInstallerService();

  List<LibraryEntry> entries = [];
  List<CuratedApp> curatedApps = [];
  Set<String> ignoredPackageNames = {};

  /// Every download-and-install performed through this app, most recent
  /// first. Capped at [_maxHistoryEntries] so it can't grow unbounded on a
  /// device that's been updating apps for years.
  List<UpdateHistoryEntry> updateHistory = [];
  static const _maxHistoryEntries = 200;

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
    ignoredPackageNames = await _loadIgnoredPackageNames();
    updateHistory = await _loadUpdateHistory();
    isLoaded = true;
    notifyListeners();
    await _backfillCuratedPackageNames();
    unawaited(checkAll());
  }

  /// Self-heals tracked favorites added before their [CuratedApp] carried a
  /// package name (or before this app knew it at all — e.g. Aurora Store):
  /// without it, device-scan matching and installed-version sync silently
  /// can't find the app, so it looks perpetually "update available" and
  /// keeps reappearing in add-app suggestions even though it's tracked.
  /// Runs once per [load], adopts the package name from the matching
  /// curated entry wherever one is now known, and immediately syncs the
  /// real installed version for it too — otherwise the false "update
  /// available" would only clear itself the next time the user happens to
  /// tap "scan device".
  Future<void> _backfillCuratedPackageNames() async {
    final backfilledIds = <String>[];
    for (final entry in entries) {
      if (!entry.app.isCurated) continue;
      if ((entry.app.packageName ?? '').trim().isNotEmpty) continue;
      final matches = curatedApps.where((c) => c.id == entry.app.id);
      final packageName = matches.isEmpty ? null : matches.first.packageName;
      if (packageName == null || packageName.trim().isEmpty) continue;
      _updateEntry(
        entry.app.id,
        (e) => e.copyWith(app: e.app.copyWith(packageName: packageName)),
      );
      backfilledIds.add(entry.app.id);
    }
    if (backfilledIds.isEmpty) return;
    await _persist();
    await Future.wait(backfilledIds.map(_syncInstalledVersion));
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

  Future<Set<String>> _loadIgnoredPackageNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(StorageKeys.ignoredPackageNames);
    return raw?.toSet() ?? {};
  }

  Future<void> _persistIgnoredPackageNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      StorageKeys.ignoredPackageNames,
      ignoredPackageNames.toList(),
    );
  }

  Future<List<UpdateHistoryEntry>> _loadUpdateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.updateHistory);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(UpdateHistoryEntry.fromJson)
        .toList();
  }

  Future<void> _persistUpdateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(updateHistory.map((e) => e.toJson()).toList());
    await prefs.setString(StorageKeys.updateHistory, raw);
  }

  Future<ReleaseResult> previewSource(AppSourceType type, String source) {
    return _resolver.resolve(type, source);
  }

  Future<TrackedApp> addCustomApp({
    required String name,
    required AppSourceType type,
    required String source,
    String? packageName,
  }) async {
    final trimmedPackageName = packageName?.trim();
    final app = TrackedApp(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      sourceType: type,
      sourceIdentifier: source,
      packageName: (trimmedPackageName == null || trimmedPackageName.isEmpty)
          ? null
          : trimmedPackageName,
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
      packageName: curated.packageName,
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
            app: e.app.copyWith(
              installedVersion: version,
              lastInstalledAt: DateTime.now(),
            ),
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

  /// Downloads and installs the latest release for [id], then records the
  /// resulting version as installed. Shared by the per-app "download &
  /// install" button and [downloadAndInstallAll], so both go through the
  /// same SHA-256 recording and package-name detection.
  Future<void> downloadAndInstall(
    String id, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    final entry = entries[index];
    final release = entry.latestRelease;
    if (release == null) return;

    final safeVersion = release.version.isEmpty ? 'latest' : release.version;
    final fileName = '${entry.app.id}-$safeVersion.apk';
    final path = await _installer.downloadApk(
      url: release.downloadUrl,
      fileName: fileName,
      onProgress: onProgress,
    );

    final sha256 = await _installer.sha256Of(path);
    _updateEntry(id, (e) => e.copyWith(lastDownloadSha256: sha256));

    await _installer.installApk(path);

    final previousVersion = entry.app.installedVersion;
    final installedVersion = release.version.isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : release.version;
    await markInstalled(id, installedVersion);
    await _recordHistory(
      appId: id,
      appName: entry.app.name,
      fromVersion: previousVersion,
      toVersion: installedVersion,
    );

    // Best-effort and slow (polls for a few seconds), so it must not hold
    // up the caller — neither the single-app "installing…" spinner nor a
    // downloadAndInstallAll() batch waiting on this app before moving on.
    unawaited(detectPackageNameAfterInstall(id));
  }

  Future<void> _recordHistory({
    required String appId,
    required String appName,
    required String? fromVersion,
    required String toVersion,
  }) async {
    final entry = UpdateHistoryEntry(
      appId: appId,
      appName: appName,
      fromVersion: fromVersion,
      toVersion: toVersion,
      installedAt: DateTime.now(),
    );
    updateHistory = [entry, ...updateHistory].take(_maxHistoryEntries).toList();
    notifyListeners();
    await _persistUpdateHistory();
  }

  /// Downloads and installs every app currently flagged as
  /// [AppCheckStatus.updateAvailable], one at a time (the system installer
  /// can't sensibly handle overlapping install intents). Apps that fail
  /// don't stop the rest of the batch.
  Future<({int succeeded, int failed})> downloadAndInstallAll() async {
    final updatableIds = entries
        .where((e) => e.status == AppCheckStatus.updateAvailable)
        .map((e) => e.app.id)
        .toList();

    var succeeded = 0;
    var failed = 0;
    for (final id in updatableIds) {
      try {
        await downloadAndInstall(id);
        succeeded++;
      } catch (_) {
        failed++;
      }
    }
    return (succeeded: succeeded, failed: failed);
  }

  /// Best-effort: if [id]'s app doesn't have a package name yet, snapshots
  /// the set of installed packages, then polls a few times for a package
  /// that wasn't there before to appear, and records it as the app's
  /// package name so future device scans (see [syncInstalledVersions]) can
  /// find it. Used right after handing an APK to the system installer,
  /// since neither Android nor open_filex reports which package the user
  /// actually confirmed installing.
  Future<void> detectPackageNameAfterInstall(
    String id, {
    int attempts = 5,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    if ((entries[index].app.packageName ?? '').trim().isNotEmpty) return;

    final before = await _deviceApps.installedPackageNames();
    for (var i = 0; i < attempts; i++) {
      await Future.delayed(interval);
      final after = await _deviceApps.installedPackageNames();
      final newPackages = after.difference(before);
      if (newPackages.isNotEmpty) {
        final detected = newPackages.first;
        _updateEntry(
          id,
          (e) => e.copyWith(app: e.app.copyWith(packageName: detected)),
        );
        await _persist();
        return;
      }
    }
  }

  /// Serializes every tracked app to JSON, for the user to back up or move
  /// to another device.
  String exportJson() =>
      jsonEncode(entries.map((e) => e.app.toJson()).toList());

  /// Merges apps from a previously-exported JSON string into the library.
  /// Apps whose id already exists are left untouched — existing
  /// install/version state always wins over an imported duplicate. Returns
  /// how many new apps were added. Throws a [FormatException] for anything
  /// that isn't a JSON list of app objects.
  Future<int> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Expected a JSON list of apps.');
    }
    final imported = decoded.cast<Map<String, dynamic>>().map(
      TrackedApp.fromJson,
    );
    final newOnes = imported
        .where((app) => !entries.any((e) => e.app.id == app.id))
        .toList();
    if (newOnes.isEmpty) return 0;

    entries = [
      ...entries,
      for (final app in newOnes)
        LibraryEntry(app: app, status: AppCheckStatus.checking),
    ];
    notifyListeners();
    await _persist();
    await Future.wait(newOnes.map((app) => checkOne(app.id)));
    return newOnes.length;
  }

  /// Scans the device for every tracked app that has a [TrackedApp.packageName]
  /// set, re-reading its installed version from the device's package
  /// manager and re-checking for updates when that version changed.
  ///
  /// Returns the number of apps eligible for the scan (i.e. with a package
  /// name set) and how many of those had their installed version updated.
  Future<({int eligible, int updated})> syncInstalledVersions() async {
    final eligible = entries
        .where((e) => (e.app.packageName ?? '').trim().isNotEmpty)
        .toList();

    final changedFlags = await Future.wait(
      eligible.map((e) => _syncInstalledVersion(e.app.id)),
    );
    final updated = changedFlags.where((changed) => changed).length;
    if (updated > 0) {
      await checkAll();
    }
    return (eligible: eligible.length, updated: updated);
  }

  /// Every app installed on the device that isn't already tracked (matched
  /// by package name) and hasn't been dismissed via [ignorePackage], for
  /// the "scan device" tab in the add-app flow — so the user can browse
  /// what's already on their phone instead of typing names in by hand.
  Future<List<InstalledApp>> installedAppsNotTracked() async {
    final installed = await _deviceApps.installedApps();
    final trackedPackageNames = entries
        .map((e) => e.app.packageName)
        .whereType<String>()
        .toSet();
    return installed
        .where(
          (app) =>
              !trackedPackageNames.contains(app.packageName) &&
              !ignoredPackageNames.contains(app.packageName),
        )
        .toList();
  }

  /// Package names of [apps] that resolve on F-Droid, checked in parallel.
  /// Backs the "Van toestel" tab's F-Droid badge and bulk-add: apps that
  /// aren't on F-Droid (or that error out) are simply left out rather than
  /// failing the whole batch.
  Future<Set<String>> findFdroidAvailable(Iterable<InstalledApp> apps) async {
    final results = await Future.wait(
      apps.map((app) async {
        final result = await _resolver.resolve(
          AppSourceType.fdroid,
          app.packageName,
        );
        return result is ReleaseSuccess ? app.packageName : null;
      }),
    );
    return results.whereType<String>().toSet();
  }

  /// Every app installed on the device, classified as tracked, ignored, or
  /// available — the combined overview shown on the "Apparaat-apps" screen
  /// in Settings.
  Future<List<DeviceAppEntry>> deviceAppOverview() async {
    final installed = await _deviceApps.installedApps();
    final trackedPackageNames = entries
        .map((e) => e.app.packageName)
        .whereType<String>()
        .toSet();
    return installed
        .map(
          (app) => DeviceAppEntry(
            app: app,
            status: trackedPackageNames.contains(app.packageName)
                ? DeviceAppStatus.tracked
                : ignoredPackageNames.contains(app.packageName)
                ? DeviceAppStatus.ignored
                : DeviceAppStatus.available,
          ),
        )
        .toList();
  }

  /// Dismisses [packageName] from add-app suggestions until
  /// [unignorePackage] is called for it.
  Future<void> ignorePackage(String packageName) async {
    if (!ignoredPackageNames.add(packageName)) return;
    notifyListeners();
    await _persistIgnoredPackageNames();
  }

  Future<void> unignorePackage(String packageName) async {
    if (!ignoredPackageNames.remove(packageName)) return;
    notifyListeners();
    await _persistIgnoredPackageNames();
  }

  Future<bool> _syncInstalledVersion(String id) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return false;
    final app = entries[index].app;
    final packageName = app.packageName;
    if (packageName == null || packageName.trim().isEmpty) return false;

    final detected = await _deviceApps.installedVersion(packageName);
    if (detected == null || detected == app.installedVersion) return false;

    _updateEntry(
      id,
      (e) => e.copyWith(
        app: e.app.copyWith(
          installedVersion: detected,
          lastInstalledAt: DateTime.now(),
        ),
      ),
    );
    await _persist();
    return true;
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
    final hasUpdate = appHasUpdate(
      sourceType: app.sourceType,
      installedVersion: app.installedVersion,
      latestVersion: info.version,
    );
    if (!hasUpdate) return AppCheckStatus.upToDate;
    if (isVersionSkipped(
      skippedVersion: app.skippedVersion,
      latestVersion: info.version,
    )) {
      return AppCheckStatus.skipped;
    }
    return AppCheckStatus.updateAvailable;
  }

  /// Silences the currently-available update for [id] until a newer release
  /// appears — for a release the user has decided not to install (a known
  /// regression, a feature they don't want) without fully un-tracking the
  /// app.
  Future<void> skipVersion(String id, String version) async {
    _updateEntry(
      id,
      (e) => e.copyWith(app: e.app.copyWith(skippedVersion: version)),
    );
    await _persist();
    await checkOne(id);
  }

  Future<void> unskipVersion(String id) async {
    _updateEntry(
      id,
      (e) => e.copyWith(app: e.app.copyWith(clearSkippedVersion: true)),
    );
    await _persist();
    await checkOne(id);
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
