import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/services/device_apps_service.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_curated_apps.dart';

class _FakeDeviceAppsService extends DeviceAppsService {
  _FakeDeviceAppsService(Map<String, String?> versions)
    : versions = Map<String, String?>.of(versions);
  final Map<String, String?> versions;

  @override
  Future<String?> installedVersion(String packageName) async =>
      versions[packageName];
}

// Network calls always fail fast so these tests only exercise the
// device-sync logic itself, not real HTTP requests.
ReleaseResolver _offlineResolver() {
  final client = MockClient((request) async => http.Response('', 503));
  return ReleaseResolver(
    github: GithubService(client: client),
    fdroid: FdroidService(client: client),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'syncInstalledVersions updates installedVersion for apps with a matching package name',
    () async {
      final deviceApps = _FakeDeviceAppsService({'com.example.app': null});
      final library = AppLibrary(
        resolver: _offlineResolver(),
        deviceApps: deviceApps,
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnapp.apk',
        packageName: 'com.example.app',
      );
      // Simulate the app being updated on the device sometime after being
      // added to App Updater (addCustomApp() already syncs whatever
      // version is on the device at add time, so the version has to
      // change afterward for a later scan to have anything to catch).
      deviceApps.versions['com.example.app'] = '2.0.0';

      final result = await library.syncInstalledVersions();

      expect(result.eligible, 1);
      expect(result.updated, 1);
      expect(library.entries.single.app.installedVersion, '2.0.0');
      expect(library.entries.single.app.lastInstalledAt, isNotNull);
    },
  );

  test('apps without a package name are not eligible for the scan', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService(const {}),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnapp.apk',
    );

    final result = await library.syncInstalledVersions();

    expect(result.eligible, 0);
    expect(result.updated, 0);
  });

  test(
    'does not report an update when the detected version matches what is already recorded',
    () async {
      final library = AppLibrary(
        resolver: _offlineResolver(),
        deviceApps: _FakeDeviceAppsService({'com.example.app': '1.0.0'}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnapp.apk',
        packageName: 'com.example.app',
      );
      await library.markInstalled(app.id, '1.0.0');

      final result = await library.syncInstalledVersions();

      expect(result.eligible, 1);
      expect(result.updated, 0);
    },
  );

  test(
    'leaves installedVersion untouched when the app is not found on the device',
    () async {
      final library = AppLibrary(
        resolver: _offlineResolver(),
        deviceApps: _FakeDeviceAppsService(const {}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnapp.apk',
        packageName: 'com.example.notinstalled',
      );

      final result = await library.syncInstalledVersions();

      expect(result.eligible, 1);
      expect(result.updated, 0);
      expect(
        library.entries
            .firstWhere((e) => e.app.id == app.id)
            .app
            .installedVersion,
        isNull,
      );
    },
  );

  test('clears installedVersion when a previously-installed app is no longer '
      'found on the device, and counts it as removed', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService(const {}),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnapp.apk',
      packageName: 'com.example.app',
    );
    await library.markInstalled(app.id, '1.0.0');

    final result = await library.syncInstalledVersions();

    expect(result.eligible, 1);
    expect(result.updated, 0);
    expect(result.removed, 1);
    final entry = library.entries.single;
    expect(entry.app.installedVersion, isNull);
    expect(entry.app.lastInstalledAt, isNull);
  });

  test('persists the synced installed version across a reload', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService({'com.example.app': '3.1.0'}),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnapp.apk',
      packageName: 'com.example.app',
    );
    await library.syncInstalledVersions();

    final reloaded = AppLibrary(
      resolver: _offlineResolver(),
      // load() now syncs every already-tracked app's installed version on
      // every open (see AppLibrary.load), so this needs a fake here too —
      // a real DeviceAppsService falls through to the installed_apps
      // platform channel, which flutter_test doesn't mock by default and
      // which hangs rather than failing fast when unmocked.
      deviceApps: _FakeDeviceAppsService({'com.example.app': '3.1.0'}),
    );
    await reloaded.load(curatedAppsOverride: testCuratedApps);

    final restored = reloaded.entries.firstWhere((e) => e.app.id == app.id);
    expect(restored.app.installedVersion, '3.1.0');
  });

  test('load() re-syncs the installed version of an already-tracked app on '
      'every open, not just apps whose package name was just backfilled — '
      'otherwise an app updated outside App Updater (Play Store, an F-Droid '
      'client, Accrescent, ...) would keep showing whatever version was last '
      'recorded until the user remembered to tap "scan device"', () async {
    final deviceApps = _FakeDeviceAppsService({'com.example.app': '1.0.0'});
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: deviceApps,
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnapp.apk',
      packageName: 'com.example.app',
    );
    expect(library.entries.single.app.installedVersion, '1.0.0');

    // The app gets updated on the device by something other than App
    // Updater (e.g. the user updated it via Play Store/F-Droid/
    // Accrescent directly) sometime before the app is next opened.
    deviceApps.versions['com.example.app'] = '2.0.0';

    final reopened = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: deviceApps,
    );
    await reopened.load(curatedAppsOverride: testCuratedApps);

    expect(reopened.entries.single.app.installedVersion, '2.0.0');
  });
}
