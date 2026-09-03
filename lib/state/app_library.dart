import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_source_type.dart';
import '../models/curated_app.dart';
import '../models/device_app_entry.dart';
import '../models/fdroid_search_result.dart';
import '../models/installed_app.dart';
import '../models/release_info.dart';
import '../models/tracked_app.dart';
import '../models/update_history_entry.dart';
import '../models/version_compare.dart';
import '../services/apk_installer_service.dart';
import '../services/device_apps_service.dart';
import '../services/fdroid_search_service.dart';
import '../services/release_resolver.dart';
import '../services/signing_service.dart';
import 'library_entry.dart';
import 'storage_keys.dart';

/// Result of a single app's device-install-state check, used by
/// [AppLibrary._syncInstalledVersion]/[AppLibrary.syncInstalledVersions].
enum _SyncOutcome { unchanged, updated, removed }

/// Thrown by [AppLibrary.downloadAndInstall] when the downloaded APK's
/// signing certificate doesn't match the installed app's, and the caller
/// either didn't confirm proceeding or has no way to ask (e.g. a batch
/// update via [AppLibrary.downloadAndInstallAll]).
class SigningMismatchException implements Exception {
  final String message;
  const SigningMismatchException(this.message);
  @override
  String toString() => message;
}

/// Owns the list of tracked apps (user-added + curated apps the user opted
/// into), the bundled list of curated suggestions, and drives release
/// checks against them. A plain ChangeNotifier, consistent with
/// [SettingsController] — no extra state-management package.
class AppLibrary extends ChangeNotifier {
  static const _kTrackedApps = StorageKeys.trackedApps;

  final ReleaseResolver _resolver;
  final DeviceAppsService _deviceApps;
  final ApkInstallerService _installer;
  final FdroidSearchService _fdroidSearch;
  final SigningService _signing;

  AppLibrary({
    ReleaseResolver? resolver,
    DeviceAppsService? deviceApps,
    ApkInstallerService? installer,
    FdroidSearchService? fdroidSearch,
    SigningService? signing,
  }) : _resolver = resolver ?? ReleaseResolver(),
       _deviceApps = deviceApps ?? DeviceAppsService(),
       _installer = installer ?? ApkInstallerService(),
       _fdroidSearch = fdroidSearch ?? FdroidSearchService(),
       _signing = signing ?? SigningService();

  List<LibraryEntry> entries = [];
  List<CuratedApp> curatedApps = [];
  Set<String> ignoredPackageNames = {};

  /// Optional GitHub personal access token, mirrored in from
  /// [SettingsController.githubToken] by the widget that owns both — kept
  /// here rather than persisted by [AppLibrary] itself since
  /// [SettingsController] already owns reading/writing it.
  String? githubToken;

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
    // Re-read every tracked app's real installed version from the device on
    // every open, not just apps whose package name was just backfilled by
    // the call above. Without this, an app updated outside App Updater
    // (Play Store, an F-Droid client, Accrescent, ...) keeps showing
    // whatever version was last recorded — including "not installed at
    // all" for one freshly added — until the user remembers to tap "scan
    // device" by hand. Awaited so the checkAll() right after compares
    // against a fresh installed version, not a stale one.
    await _syncAllInstalledVersions();
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
    return _resolver.resolve(type, source, githubToken: githubToken);
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
    // If this app is already installed (a package name was supplied and
    // matches something on the device), pick up its real version right
    // away — otherwise it would show a false "update available" until the
    // next app open or manual "scan device".
    await _syncInstalledVersion(app.id);
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
    await _syncInstalledVersion(app.id);
    await checkOne(app.id);
  }

  /// Downloads and installs the app tracked at [id] if it isn't already on
  /// the device — called from the add-app screen right after a user adds a
  /// custom source or a favorite, so "add" also gets the app installed
  /// without a separate manual tap. Deliberately not wired into
  /// [addCustomApp]/[addFavorite] themselves: those are also used by
  /// paths that must stay side-effect-free (curated-package-name backfill,
  /// JSON import, the device-apps "add all via F-Droid" bulk action, whose
  /// apps are already installed by definition), and a live device-package
  /// query plus a real download is too heavy a side effect to attach to
  /// every caller of a plain "track this app" operation.
  ///
  /// Only runs when a package name is known — without one there's no
  /// reliable way to ask the device's package manager whether it's already
  /// installed, and installing blind risks prompting for an app the user
  /// already has under a different source. Best-effort: a failure here (no
  /// network, no release found, install cancelled) is swallowed so the app
  /// stays tracked and the user can retry manually.
  Future<void> installIfMissingFromDevice(String id) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    final packageName = entries[index].app.packageName?.trim();
    if (packageName == null || packageName.isEmpty) return;
    try {
      final installedVersion = await _deviceApps.installedVersion(packageName);
      if (installedVersion != null) return;
      await downloadAndInstall(id);
    } catch (_) {
      // Best-effort — leave it tracked so the user can retry manually.
    }
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
  /// [confirmSigningMismatch] is asked to confirm the install when the
  /// downloaded APK's signing certificate doesn't match the certificate of
  /// the app currently installed under the same package name — see
  /// [SigningService]. When it's omitted (e.g. from [downloadAndInstallAll],
  /// which can't sensibly show a dialog per app) or returns `false`, a
  /// detected mismatch throws [SigningMismatchException] instead of
  /// installing.
  Future<void> downloadAndInstall(
    String id, {
    void Function(int received, int? total)? onProgress,
    Future<bool> Function()? confirmSigningMismatch,
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

    final packageName = entry.app.packageName;
    if (packageName != null && packageName.trim().isNotEmpty) {
      final installedHashes = await _signing.installedCertificateHashes(
        packageName,
      );
      final apkHashes = await _signing.apkCertificateHashes(path);
      final mismatch =
          installedHashes.isNotEmpty &&
          apkHashes.isNotEmpty &&
          installedHashes.intersection(apkHashes).isEmpty;
      if (mismatch) {
        final proceed = confirmSigningMismatch == null
            ? false
            : await confirmSigningMismatch();
        if (!proceed) {
          throw const SigningMismatchException(
            'De signing-key van deze download komt niet overeen met de '
            'geïnstalleerde app.',
          );
        }
      }
    }

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
    // Accrescent apps have no downloadable file (see AccrescentService) —
    // they're updated by opening Accrescent itself, one at a time, from the
    // detail screen, so they're left out of the batch entirely rather than
    // counted as a failure.
    final updatableIds = entries
        .where(
          (e) =>
              e.status == AppCheckStatus.updateAvailable &&
              e.app.sourceType != AppSourceType.accrescent,
        )
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
  ///
  /// Only commits when exactly one new package appeared. If something else
  /// happens to install or update in the same window (e.g. an unrelated
  /// Play Store auto-update landing at the same moment), guessing which of
  /// several new packages is the right one risks silently attaching this
  /// app's tracking to a completely unrelated package — permanently wrong
  /// version info is worse than no package name at all, so this keeps
  /// polling instead and simply gives up if it never resolves to exactly
  /// one.
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
      if (newPackages.length == 1) {
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
  /// manager and re-checking for updates when that version changed, or
  /// resetting it when the app was removed from the device outside App
  /// Updater — see [_syncInstalledVersion].
  ///
  /// Returns the number of apps eligible for the scan (i.e. with a package
  /// name set), how many had their installed version updated, and how many
  /// were found to no longer be on the device.
  Future<({int eligible, int updated, int removed})>
  syncInstalledVersions() async {
    final eligibleCount = entries
        .where((e) => (e.app.packageName ?? '').trim().isNotEmpty)
        .length;

    final outcomes = await _syncAllInstalledVersions();
    final updated = outcomes.where((o) => o == _SyncOutcome.updated).length;
    final removed = outcomes.where((o) => o == _SyncOutcome.removed).length;
    if (updated > 0 || removed > 0) {
      await checkAll();
    }
    return (eligible: eligibleCount, updated: updated, removed: removed);
  }

  /// The actual per-app work behind [syncInstalledVersions] and the
  /// unconditional sync [load] does on every app open — pulled out so both
  /// call sites share one implementation.
  Future<List<_SyncOutcome>> _syncAllInstalledVersions() {
    final eligible = entries.where(
      (e) => (e.app.packageName ?? '').trim().isNotEmpty,
    );
    return Future.wait(eligible.map((e) => _syncInstalledVersion(e.app.id)));
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

  /// Full-text search across F-Droid's entire catalog (not just apps
  /// already installed on the device) — backs the "F-Droid" tab in the
  /// add-app flow. Lets exceptions from [FdroidSearchService] propagate so
  /// the screen can show a real error state instead of a silent empty list.
  Future<List<FdroidSearchResult>> searchFdroid(String query) {
    return _fdroidSearch.search(query);
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

  /// Re-reads [id]'s installed version from the device's package manager.
  /// When the app is no longer found there but this app still remembers an
  /// [TrackedApp.installedVersion] for it, that's treated as "removed
  /// outside App Updater" rather than silently ignored — the recorded
  /// version (and [TrackedApp.lastInstalledAt]) is cleared so the app
  /// naturally reappears under "needs installing" on the next status check,
  /// the same way a freshly-added, never-installed app does.
  Future<_SyncOutcome> _syncInstalledVersion(String id) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return _SyncOutcome.unchanged;
    final app = entries[index].app;
    final packageName = app.packageName;
    if (packageName == null || packageName.trim().isEmpty) {
      return _SyncOutcome.unchanged;
    }

    // Now called on every load()/add, not just the manual "scan device"
    // button, so a plugin hiccup here (a stray platform-channel error, a
    // device that rejects the query) must not be allowed to blow up the
    // add/load flow — treat it the same as "couldn't determine", i.e. no
    // change, and leave the previously-known version as-is.
    String? detected;
    try {
      detected = await _deviceApps.installedVersion(packageName);
    } catch (_) {
      return _SyncOutcome.unchanged;
    }
    if (detected == null) {
      if (app.installedVersion == null) return _SyncOutcome.unchanged;
      _updateEntry(
        id,
        (e) => e.copyWith(
          app: e.app.copyWith(
            clearInstalledVersion: true,
            clearLastInstalledAt: true,
          ),
        ),
      );
      await _persist();
      return _SyncOutcome.removed;
    }
    if (detected == app.installedVersion) return _SyncOutcome.unchanged;

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
    return _SyncOutcome.updated;
  }

  Future<void> checkOne(String id) async {
    final index = entries.indexWhere((e) => e.app.id == id);
    if (index == -1) return;
    final entry = entries[index];

    _updateEntry(id, (e) => e.copyWith(status: AppCheckStatus.checking));

    final result = await _resolver.resolve(
      entry.app.sourceType,
      entry.app.sourceIdentifier,
      githubToken: githubToken,
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
