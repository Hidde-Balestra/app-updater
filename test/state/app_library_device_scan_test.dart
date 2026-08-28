import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/installed_app.dart';
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
  final List<InstalledApp> apps;
  _FakeDeviceAppsService(this.apps);

  @override
  Future<List<InstalledApp>> installedApps() async => apps;
}

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

  test('returns every installed app when nothing is tracked yet', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService([
        const InstalledApp(
          name: 'One',
          packageName: 'com.example.one',
          versionName: '1.0.0',
        ),
        const InstalledApp(
          name: 'Two',
          packageName: 'com.example.two',
          versionName: '2.0.0',
        ),
      ]),
    );
    await library.load(curatedAppsOverride: testCuratedApps);

    final result = await library.installedAppsNotTracked();

    expect(result.map((a) => a.packageName), [
      'com.example.one',
      'com.example.two',
    ]);
  });

  test('excludes installed apps already tracked by package name', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService([
        const InstalledApp(
          name: 'One',
          packageName: 'com.example.one',
          versionName: '1.0.0',
        ),
        const InstalledApp(
          name: 'Two',
          packageName: 'com.example.two',
          versionName: '2.0.0',
        ),
      ]),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'One',
      type: AppSourceType.direct,
      source: 'https://example.com/one.apk',
      packageName: 'com.example.one',
    );

    final result = await library.installedAppsNotTracked();

    expect(result.map((a) => a.packageName), ['com.example.two']);
  });

  test('tracked apps without a package name never exclude anything', () async {
    final library = AppLibrary(
      resolver: _offlineResolver(),
      deviceApps: _FakeDeviceAppsService([
        const InstalledApp(
          name: 'One',
          packageName: 'com.example.one',
          versionName: '1.0.0',
        ),
      ]),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'Untracked source',
      type: AppSourceType.direct,
      source: 'https://example.com/other.apk',
    );

    final result = await library.installedAppsNotTracked();

    expect(result.map((a) => a.packageName), ['com.example.one']);
  });
}
