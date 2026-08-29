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
  _FakeDeviceAppsService(this._versions);
  final Map<String, String?> _versions;

  @override
  Future<String?> installedVersion(String packageName) async =>
      _versions[packageName];
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
      final library = AppLibrary(
        resolver: _offlineResolver(),
        deviceApps: _FakeDeviceAppsService({'com.example.app': '2.0.0'}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnapp.apk',
        packageName: 'com.example.app',
      );

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

    final reloaded = AppLibrary(resolver: _offlineResolver());
    await reloaded.load(curatedAppsOverride: testCuratedApps);

    final restored = reloaded.entries.firstWhere((e) => e.app.id == app.id);
    expect(restored.app.installedVersion, '3.1.0');
  });
}
