import 'dart:convert';

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

class _FakeDeviceAppsService extends DeviceAppsService {
  final Map<String, String> versionsByPackage;
  _FakeDeviceAppsService(this.versionsByPackage);

  @override
  Future<String?> installedVersion(String packageName) async =>
      versionsByPackage[packageName];
}

// A resolver whose network calls always fail fast, so these tests only
// exercise the curated_apps.json asset loading and stay hermetic (no real
// HTTP requests from a unit test).
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
    'load() seeds the required curated apps from the bundled asset',
    () async {
      final library = AppLibrary(resolver: _offlineResolver());
      await library.load();

      final ids = library.curatedApps.map((c) => c.id).toSet();
      expect(
        ids,
        containsAll({
          'taalleer',
          'task_planner',
          'musicplayer',
          'fdroid',
          'aurora_store',
          'molly',
        }),
      );

      final taalleer = library.curatedApps.firstWhere(
        (c) => c.id == 'taalleer',
      );
      expect(taalleer.sourceIdentifier, 'Hidde-Balestra/taalleer');

      final taskPlanner = library.curatedApps.firstWhere(
        (c) => c.id == 'task_planner',
      );
      expect(taskPlanner.sourceIdentifier, 'Hidde-Balestra/Task_Planner');

      final musicPlayer = library.curatedApps.firstWhere(
        (c) => c.id == 'musicplayer',
      );
      expect(
        musicPlayer.sourceIdentifier,
        'privacy-creator/musicplayer-flutter',
      );

      final fdroid = library.curatedApps.firstWhere((c) => c.id == 'fdroid');
      expect(fdroid.infoUrl, 'https://f-droid.org/en/');

      final auroraStore = library.curatedApps.firstWhere(
        (c) => c.id == 'aurora_store',
      );
      expect(auroraStore.sourceType, AppSourceType.gitlab);
      expect(auroraStore.sourceIdentifier, 'AuroraOSS/AuroraStore');
      expect(auroraStore.packageName, 'com.aurora.store');

      final molly = library.curatedApps.firstWhere((c) => c.id == 'molly');
      expect(molly.sourceType, AppSourceType.github);
      expect(molly.sourceIdentifier, 'mollyim/mollyim-android');
      expect(molly.packageName, 'im.molly.app');
    },
  );

  test(
    'a freshly loaded library with no tracked apps offers all curated apps as favorites',
    () async {
      final library = AppLibrary(resolver: _offlineResolver());
      await library.load();

      expect(library.availableFavorites.length, library.curatedApps.length);
    },
  );

  test(
    'addFavorite carries the curated package name onto the tracked app',
    () async {
      final library = AppLibrary(resolver: _offlineResolver());
      await library.load();

      final auroraStore = library.curatedApps.firstWhere(
        (c) => c.id == 'aurora_store',
      );
      await library.addFavorite(auroraStore);

      final entry = library.entries.single;
      expect(entry.app.packageName, 'com.aurora.store');
    },
  );

  test(
    'load() backfills a package name for a favorite added before the '
    'curated entry had one, and syncs its real installed version too',
    () async {
      // Simulates a tracked app persisted by an older app version, before
      // aurora_store's package name was known — installedVersion is null so
      // it would otherwise keep showing a false "update available" until the
      // user happens to tap "scan device".
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'library.trackedApps',
        jsonEncode([
          {
            'id': 'aurora_store',
            'name': 'Aurora Store',
            'sourceType': 'gitlab',
            'sourceIdentifier': 'AuroraOSS/AuroraStore',
            'isCurated': true,
            'installedVersion': null,
            'packageName': null,
          },
        ]),
      );

      final library = AppLibrary(
        resolver: _offlineResolver(),
        deviceApps: _FakeDeviceAppsService({'com.aurora.store': '4.8.4'}),
      );
      await library.load();

      final entry = library.entries.single;
      expect(entry.app.packageName, 'com.aurora.store');
      expect(entry.app.installedVersion, '4.8.4');
    },
  );
}
