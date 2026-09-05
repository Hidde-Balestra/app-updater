import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/services/codeberg_service.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/gitlab_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/state/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_curated_apps.dart';

ReleaseResolver _resolverReturning(http.Response response) {
  final client = MockClient((request) async => response);
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

  group('lastCheckedAt', () {
    test('is recorded after a check that finds no releases', () async {
      final library = AppLibrary(
        resolver: _resolverReturning(http.Response('', 404)),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );

      expect(library.entries.single.lastCheckedAt, isNotNull);
      expect(library.entries.single.status, AppCheckStatus.noReleases);
    });

    test('is recorded on a resolve error too', () async {
      final library = AppLibrary(
        resolver: _resolverReturning(http.Response('', 500)),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );

      expect(library.entries.single.status, AppCheckStatus.error);
      expect(library.entries.single.lastCheckedAt, isNotNull);
    });

    test('advances on a later check', () async {
      final library = AppLibrary(
        resolver: _resolverReturning(http.Response('', 500)),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );
      final firstCheckedAt = library.entries.single.lastCheckedAt!;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await library.checkOne(app.id);

      expect(
        library.entries.single.lastCheckedAt!.isAfter(firstCheckedAt),
        isTrue,
      );
    });
  });

  group('gitlab/codeberg tokens', () {
    test('checkOne sends the GitLab token to a GitLab-sourced app', () async {
      String? tokenHeader;
      final client = MockClient((request) async {
        tokenHeader = request.headers['PRIVATE-TOKEN'];
        return http.Response('', 404);
      });
      final library = AppLibrary(
        resolver: ReleaseResolver(gitlab: GitlabService(client: client)),
      );
      library.gitlabToken = 'glpat-example';
      await library.load(curatedAppsOverride: testCuratedApps);

      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.gitlab,
        source: 'owner/repo',
      );

      expect(tokenHeader, 'glpat-example');
    });

    test(
      'checkOne sends the Codeberg token to a Codeberg-sourced app',
      () async {
        String? authHeader;
        final client = MockClient((request) async {
          authHeader = request.headers['Authorization'];
          return http.Response('', 404);
        });
        final library = AppLibrary(
          resolver: ReleaseResolver(codeberg: CodebergService(client: client)),
        );
        library.codebergToken = 'codeberg-example';
        await library.load(curatedAppsOverride: testCuratedApps);

        await library.addCustomApp(
          name: 'MijnApp',
          type: AppSourceType.codeberg,
          source: 'owner/repo',
        );

        expect(authHeader, 'token codeberg-example');
      },
    );
  });
}
