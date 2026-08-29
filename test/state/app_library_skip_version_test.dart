import 'dart:convert';

import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/state/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_curated_apps.dart';

/// A resolver whose GitHub response's tag_name is read fresh from
/// [tagName] on every call, so a test can simulate a newer release
/// appearing between two checkOne() calls. F-Droid always fails fast since
/// nothing here uses it.
ReleaseResolver _resolverFor(String Function() tagName) {
  final client = MockClient((request) async {
    return http.Response(
      jsonEncode({
        'tag_name': tagName(),
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'https://x/app.apk',
            'size': 1,
          },
        ],
      }),
      200,
    );
  });
  return ReleaseResolver(
    github: GithubService(client: client),
    fdroid: FdroidService(
      client: MockClient((r) async => http.Response('', 503)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'skipVersion moves an updatable app from updateAvailable to skipped',
    () async {
      final library = AppLibrary(resolver: _resolverFor(() => 'v1.1.0'));
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );
      await library.markInstalled(app.id, '1.0.0');
      await library.checkOne(app.id);
      expect(library.entries.single.status, AppCheckStatus.updateAvailable);

      await library.skipVersion(app.id, '1.1.0');

      expect(library.entries.single.status, AppCheckStatus.skipped);
      expect(library.entries.single.app.skippedVersion, '1.1.0');
    },
  );

  test('unskipVersion returns a skipped app to updateAvailable', () async {
    final library = AppLibrary(resolver: _resolverFor(() => 'v1.1.0'));
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
    );
    await library.markInstalled(app.id, '1.0.0');
    await library.checkOne(app.id);
    await library.skipVersion(app.id, '1.1.0');
    expect(library.entries.single.status, AppCheckStatus.skipped);

    await library.unskipVersion(app.id);

    expect(library.entries.single.status, AppCheckStatus.updateAvailable);
    expect(library.entries.single.app.skippedVersion, isNull);
  });

  test(
    'a newer release than the skipped one is reported as updateAvailable again',
    () async {
      var tag = 'v1.1.0';
      final library = AppLibrary(resolver: _resolverFor(() => tag));
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );
      await library.markInstalled(app.id, '1.0.0');
      await library.checkOne(app.id);
      await library.skipVersion(app.id, '1.1.0');
      expect(library.entries.single.status, AppCheckStatus.skipped);

      tag = 'v1.2.0';
      await library.checkOne(app.id);

      expect(library.entries.single.status, AppCheckStatus.updateAvailable);
    },
  );

  test('skipping survives a reload of the library', () async {
    final library = AppLibrary(resolver: _resolverFor(() => 'v1.1.0'));
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
    );
    await library.markInstalled(app.id, '1.0.0');
    await library.checkOne(app.id);
    await library.skipVersion(app.id, '1.1.0');

    final reloaded = AppLibrary(resolver: _resolverFor(() => 'v1.1.0'));
    await reloaded.load(curatedAppsOverride: testCuratedApps);
    // load() kicks off its own checkAll() without awaiting it, so the
    // freshly-loaded status is still "checking" at this point — force one
    // explicit check before asserting on it.
    await reloaded.checkOne(reloaded.entries.single.app.id);

    expect(reloaded.entries.single.app.skippedVersion, '1.1.0');
    expect(reloaded.entries.single.status, AppCheckStatus.skipped);
  });
}
