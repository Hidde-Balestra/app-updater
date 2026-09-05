import 'dart:convert';

import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_curated_apps.dart';

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
    'exportJson round-trips through importJson into a fresh library',
    () async {
      final source = AppLibrary(resolver: _offlineResolver());
      await source.load(curatedAppsOverride: testCuratedApps);
      await source.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
      );
      final exported = source.exportJson();

      // SharedPreferences.getInstance() is a single shared mock store per
      // test, even across separate AppLibrary instances — reset it here to
      // simulate importing into a genuinely separate install (e.g. a new
      // device) rather than one that happens to already have `source`'s
      // data persisted underneath it.
      SharedPreferences.setMockInitialValues({});
      final target = AppLibrary(resolver: _offlineResolver());
      await target.load(curatedAppsOverride: testCuratedApps);
      final added = await target.importJson(exported);

      expect(added, 1);
      expect(target.entries.single.app.name, 'MijnBudget');
    },
  );

  test('importJson skips apps that are already tracked by id', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnBudget',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnbudget.apk',
    );

    final added = await library.importJson(library.exportJson());

    expect(added, 0);
    expect(library.entries, hasLength(1));
    expect(library.entries.single.app.id, app.id);
  });

  test('importJson adds only the apps not already present', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'Existing',
      type: AppSourceType.direct,
      source: 'https://example.com/existing.apk',
    );

    final incoming = jsonEncode([
      ...jsonDecode(library.exportJson()) as List,
      {
        'id': 'new-id',
        'name': 'NewApp',
        'sourceType': 'direct',
        'sourceIdentifier': 'https://example.com/new.apk',
        'isCurated': false,
        'installedVersion': null,
      },
    ]);

    final added = await library.importJson(incoming);

    expect(added, 1);
    expect(library.entries, hasLength(2));
    expect(library.entries.any((e) => e.app.id == 'new-id'), isTrue);
  });

  test('importJson throws a FormatException for non-list JSON', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load(curatedAppsOverride: testCuratedApps);

    expect(
      () => library.importJson(jsonEncode({'not': 'a list'})),
      throwsFormatException,
    );
  });

  test('importJson throws for text that is not JSON at all', () async {
    final library = AppLibrary(resolver: _offlineResolver());
    await library.load(curatedAppsOverride: testCuratedApps);

    expect(() => library.importJson('not json'), throwsFormatException);
  });

  test('importJson persists imported apps across a reload', () async {
    final source = AppLibrary(resolver: _offlineResolver());
    await source.load(curatedAppsOverride: testCuratedApps);
    await source.addCustomApp(
      name: 'MijnBudget',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnbudget.apk',
    );

    final target = AppLibrary(resolver: _offlineResolver());
    await target.load(curatedAppsOverride: testCuratedApps);
    await target.importJson(source.exportJson());

    final reloaded = AppLibrary(resolver: _offlineResolver());
    await reloaded.load(curatedAppsOverride: testCuratedApps);

    expect(reloaded.entries.single.app.name, 'MijnBudget');
  });

  group('exportBackupData/importBackupData', () {
    test(
      'round-trips tracked apps and ignored packages into a fresh library',
      () async {
        final source = AppLibrary(resolver: _offlineResolver());
        await source.load(curatedAppsOverride: testCuratedApps);
        await source.addCustomApp(
          name: 'MijnBudget',
          type: AppSourceType.direct,
          source: 'https://example.com/mijnbudget.apk',
        );
        await source.ignorePackage('com.example.ignored');
        final backup = source.exportBackupData();

        SharedPreferences.setMockInitialValues({});
        final target = AppLibrary(resolver: _offlineResolver());
        await target.load(curatedAppsOverride: testCuratedApps);
        final added = await target.importBackupData(backup);

        expect(added, 1);
        expect(target.entries.single.app.name, 'MijnBudget');
        expect(target.ignoredPackageNames, {'com.example.ignored'});
      },
    );

    test(
      'merges newly-ignored packages without dropping existing ones',
      () async {
        final library = AppLibrary(resolver: _offlineResolver());
        await library.load(curatedAppsOverride: testCuratedApps);
        await library.ignorePackage('com.example.already');

        await library.importBackupData({
          'trackedApps': <dynamic>[],
          'ignoredPackageNames': ['com.example.new'],
        });

        expect(library.ignoredPackageNames, {
          'com.example.already',
          'com.example.new',
        });
      },
    );

    test('tolerates a backup with no ignoredPackageNames key', () async {
      final library = AppLibrary(resolver: _offlineResolver());
      await library.load(curatedAppsOverride: testCuratedApps);

      final added = await library.importBackupData({
        'trackedApps': <dynamic>[],
      });

      expect(added, 0);
      expect(library.ignoredPackageNames, isEmpty);
    });

    test('persists the ignored packages restored via a backup', () async {
      final source = AppLibrary(resolver: _offlineResolver());
      await source.load(curatedAppsOverride: testCuratedApps);
      await source.ignorePackage('com.example.ignored');
      final backup = source.exportBackupData();

      SharedPreferences.setMockInitialValues({});
      final target = AppLibrary(resolver: _offlineResolver());
      await target.load(curatedAppsOverride: testCuratedApps);
      await target.importBackupData(backup);

      final reloaded = AppLibrary(resolver: _offlineResolver());
      await reloaded.load(curatedAppsOverride: testCuratedApps);
      expect(reloaded.ignoredPackageNames, {'com.example.ignored'});
    });
  });
}
