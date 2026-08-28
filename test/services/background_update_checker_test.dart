import 'dart:convert';

import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/tracked_app.dart';
import 'package:app_updater/services/background_update_checker.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/notification_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  final List<List<String>> calls = [];

  @override
  Future<void> showUpdatesAvailable(List<String> appNames) async {
    calls.add(appNames);
  }
}

final _outdatedApp = TrackedApp(
  id: 'a',
  name: 'TaalLeer',
  sourceType: AppSourceType.github,
  sourceIdentifier: 'Hidde-Balestra/taalleer',
  installedVersion: '1.0.0',
);

final _upToDateApp = TrackedApp(
  id: 'b',
  name: 'F-Droid',
  sourceType: AppSourceType.fdroid,
  sourceIdentifier: 'org.fdroid.fdroid',
  installedVersion: '1.20',
);

ReleaseResolver _resolver() {
  final client = MockClient((request) async {
    if (request.url.host == 'api.github.com') {
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.1.0',
          'assets': [
            {
              'name': 'taalleer.apk',
              'browser_download_url': 'https://x/taalleer.apk',
              'size': 1,
            },
          ],
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'packageName': 'org.fdroid.fdroid',
        'suggestedVersionCode': 1,
        'packages': [
          {'versionName': '1.20', 'versionCode': 1},
        ],
      }),
      200,
    );
  });
  return ReleaseResolver(
    github: GithubService(client: client),
    fdroid: FdroidService(client: client),
  );
}

Future<void> _seedTrackedApps(List<TrackedApp> apps) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    StorageKeys.trackedApps,
    jsonEncode(apps.map((a) => a.toJson()).toList()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('does nothing when there are no tracked apps', () async {
    final notifications = _FakeNotificationService();
    await BackgroundUpdateChecker(
      resolver: _resolver(),
      notifications: notifications,
    ).run();

    expect(notifications.calls, isEmpty);
  });

  test('does nothing when notifications are disabled in settings', () async {
    await _seedTrackedApps([_outdatedApp]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.notificationsEnabled, false);

    final notifications = _FakeNotificationService();
    await BackgroundUpdateChecker(
      resolver: _resolver(),
      notifications: notifications,
    ).run();

    expect(notifications.calls, isEmpty);
  });

  test('notifies with the names of apps that have an update', () async {
    await _seedTrackedApps([_outdatedApp, _upToDateApp]);

    final notifications = _FakeNotificationService();
    await BackgroundUpdateChecker(
      resolver: _resolver(),
      notifications: notifications,
    ).run();

    expect(notifications.calls, [
      ['TaalLeer'],
    ]);
  });

  test('does not notify when no tracked app has an update', () async {
    await _seedTrackedApps([_upToDateApp]);

    final notifications = _FakeNotificationService();
    await BackgroundUpdateChecker(
      resolver: _resolver(),
      notifications: notifications,
    ).run();

    expect(notifications.calls, isEmpty);
  });
}
