import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/release_info.dart';
import '../models/tracked_app.dart';
import '../models/version_compare.dart';
import '../state/storage_keys.dart';
import 'notification_service.dart';
import 'release_resolver.dart';

/// The headless logic run by [callbackDispatcher] on WorkManager's schedule:
/// reads the tracked apps straight out of SharedPreferences (there's no
/// widget tree / [AppLibrary] in a background isolate), checks each one for
/// an update, and raises a single notification if any were found.
///
/// Deliberately does not write anything back to SharedPreferences — the
/// live [AppLibrary] instance re-checks and reconciles state itself the
/// next time the app is opened, so this only needs read access.
class BackgroundUpdateChecker {
  final ReleaseResolver _resolver;
  final NotificationService _notifications;

  BackgroundUpdateChecker({
    ReleaseResolver? resolver,
    NotificationService? notifications,
  }) : _resolver = resolver ?? ReleaseResolver(),
       _notifications = notifications ?? NotificationService();

  Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool(StorageKeys.notificationsEnabled) ?? true;
    if (!notificationsEnabled) return;

    final raw = prefs.getString(StorageKeys.trackedApps);
    if (raw == null || raw.isEmpty) return;

    final apps = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(TrackedApp.fromJson)
        .toList();
    if (apps.isEmpty) return;

    final updatableNames = <String>[];
    for (final app in apps) {
      final result = await _resolver.resolve(
        app.sourceType,
        app.sourceIdentifier,
      );
      if (result case ReleaseSuccess(:final info)) {
        final hasUpdate = appHasUpdate(
          sourceType: app.sourceType,
          installedVersion: app.installedVersion,
          latestVersion: info.version,
        );
        if (hasUpdate) updatableNames.add(app.name);
      }
    }

    if (updatableNames.isNotEmpty) {
      await _notifications.showUpdatesAvailable(updatableNames);
    }
  }
}
