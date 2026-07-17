import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('load() seeds the four required curated apps from the bundled asset', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load();

    final ids = library.curatedApps.map((c) => c.id).toSet();
    expect(
      ids,
      containsAll({'taalleer', 'task_planner', 'musicplayer', 'fdroid'}),
    );

    final taalleer = library.curatedApps.firstWhere((c) => c.id == 'taalleer');
    expect(taalleer.sourceIdentifier, 'Hidde-Balestra/taalleer');

    final taskPlanner = library.curatedApps.firstWhere((c) => c.id == 'task_planner');
    expect(taskPlanner.sourceIdentifier, 'Hidde-Balestra/Task_Planner');

    final musicPlayer = library.curatedApps.firstWhere((c) => c.id == 'musicplayer');
    expect(musicPlayer.sourceIdentifier, 'privacy-creator/musicplayer-flutter');

    final fdroid = library.curatedApps.firstWhere((c) => c.id == 'fdroid');
    expect(fdroid.infoUrl, 'https://f-droid.org/en/');
  });

  test('a freshly loaded library with no tracked apps offers all curated apps as favorites', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load();

    expect(library.availableFavorites.length, library.curatedApps.length);
  });
}
