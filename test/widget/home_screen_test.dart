import 'dart:convert';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/home_screen.dart';
import 'package:app_updater/services/apk_installer_service.dart';
import 'package:app_updater/services/device_apps_service.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/state/library_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_apk_installer_service.dart';
import '../support/fake_curated_apps.dart';
import '../support/fake_signing_service.dart';

class _FakeDeviceAppsService extends DeviceAppsService {
  _FakeDeviceAppsService([this._versions = const {}]);
  final Map<String, String?> _versions;

  @override
  Future<String?> installedVersion(String packageName) async =>
      _versions[packageName];
}

AppLibrary _offlineLibrary({
  DeviceAppsService? deviceApps,
  ApkInstallerService? installer,
}) {
  final client = MockClient((request) async => http.Response('', 503));
  return AppLibrary(
    resolver: ReleaseResolver(
      github: GithubService(client: client),
      fdroid: FdroidService(client: client),
    ),
    deviceApps: deviceApps ?? _FakeDeviceAppsService(),
    installer: installer,
    signing: FakeSigningService(),
  );
}

/// A library whose GitHub source always resolves to version 2.0.0 with a
/// fixed changelog, regardless of repo — used for the "updates available"
/// sort-order and changelog-preview tests, where the exact release content
/// doesn't matter as long as it's consistent.
AppLibrary _githubLibrary() {
  final client = MockClient((request) async {
    if (request.url.host == 'api.github.com') {
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.0.0',
          'body': 'Fixed a crash on startup.\nMinor UI tweaks.',
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
    }
    return http.Response('', 503);
  });
  return AppLibrary(
    resolver: ReleaseResolver(
      github: GithubService(client: client),
      fdroid: FdroidService(client: client),
    ),
    signing: FakeSigningService(),
  );
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('nl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the empty state when there are no tracked apps', (
    tester,
  ) async {
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(HomeScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('Nog geen apps'), findsOneWidget);
  });

  testWidgets(
    'renders a custom app under "Mijn apps" and a favorite under "Aangeraden apps"',
    (tester) async {
      final library = _offlineLibrary(
        deviceApps: _FakeDeviceAppsService({'com.example.mijnbudget': '1.0.0'}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      // Already installed (packageName + a matching installedVersion), so
      // it's up to date and lands in "Mijn apps" rather than the separate
      // "Updates beschikbaar" section.
      await library.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
        packageName: 'com.example.mijnbudget',
      );
      await library.syncInstalledVersions();
      await library.addFavorite(library.curatedApps.first);

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      // SectionHeader renders titles upper-cased.
      expect(find.text('MIJN APPS'), findsOneWidget);
      expect(find.text('MijnBudget'), findsOneWidget);
      expect(find.text('AANGERADEN APPS'), findsOneWidget);
      expect(find.text(library.curatedApps.first.name), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "scan device" with no eligible apps shows the none-eligible message',
    (tester) async {
      final library = _offlineLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
      );

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Geen van je apps heeft een package naam ingesteld. "
          "Voeg er een toe bij ‘Eigen app’ voor automatische synchronisatie.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping "scan device" syncs the installed version of eligible apps and reports the result',
    (tester) async {
      final library = _offlineLibrary(
        deviceApps: _FakeDeviceAppsService({'com.example.app': '9.9.9'}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
        packageName: 'com.example.app',
      );

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();

      expect(find.text('1 van 1 apps gesynchroniseerd'), findsOneWidget);
      expect(library.entries.single.app.installedVersion, '9.9.9');
    },
  );

  testWidgets(
    'tapping "scan device" reports an app no longer found on the device',
    (tester) async {
      final library = _offlineLibrary(
        deviceApps: _FakeDeviceAppsService(const {}),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
        packageName: 'com.example.app',
      );
      await library.markInstalled(app.id, '1.0.0');

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '0 van 1 apps gesynchroniseerd, 1 niet meer gevonden op je toestel',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows an update-all banner and installs every updatable app on tap',
    (tester) async {
      final installer = FakeApkInstallerService();
      final library = _offlineLibrary(installer: installer);
      await library.load(curatedAppsOverride: testCuratedApps);
      // A package name is set up front so the fire-and-forget
      // detectPackageNameAfterInstall() call inside downloadAndInstall()
      // returns immediately instead of polling in the background for the
      // rest of the test run.
      await library.addCustomApp(
        name: 'MijnBudget',
        type: AppSourceType.direct,
        source: 'https://example.com/mijnbudget.apk',
        packageName: 'com.example.mijnbudget',
      );

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      expect(find.text('1 updates beschikbaar'), findsOneWidget);

      await tester.tap(find.text('Alles updaten'));
      await tester.pumpAndSettle();

      expect(find.text('1 van 1 apps bijgewerkt'), findsOneWidget);
      expect(installer.installedPaths, hasLength(1));
      expect(library.entries.single.status, AppCheckStatus.upToDate);
    },
  );

  testWidgets('groups an updatable app under its own section, separate from an '
      'up-to-date app in "Mijn apps"', (tester) async {
    final library = _offlineLibrary(
      deviceApps: _FakeDeviceAppsService({'com.example.uptodate': '1.0.0'}),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    // No package name set, so checkAll() can't compare against an
    // installed version and this one stays in "needs update".
    await library.addCustomApp(
      name: 'NeedsUpdate',
      type: AppSourceType.direct,
      source: 'https://example.com/needsupdate.apk',
    );
    await library.addCustomApp(
      name: 'UpToDate',
      type: AppSourceType.direct,
      source: 'https://example.com/uptodate.apk',
      packageName: 'com.example.uptodate',
    );
    await library.syncInstalledVersions();

    await tester.pumpWidget(_wrap(HomeScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('UPDATES BESCHIKBAAR'), findsOneWidget);
    expect(find.text('MIJN APPS'), findsOneWidget);

    final updatesSection = tester.getCenter(find.text('UPDATES BESCHIKBAAR'));
    final myAppsSection = tester.getCenter(find.text('MIJN APPS'));
    final needsUpdateTile = tester.getCenter(find.text('NeedsUpdate'));
    final upToDateTile = tester.getCenter(find.text('UpToDate'));

    // NeedsUpdate sits between the two section headers, and UpToDate
    // below the "Mijn apps" header — i.e. each app appears exactly once,
    // grouped under the right section.
    expect(needsUpdateTile.dy, greaterThan(updatesSection.dy));
    expect(needsUpdateTile.dy, lessThan(myAppsSection.dy));
    expect(upToDateTile.dy, greaterThan(myAppsSection.dy));
  });

  testWidgets(
    'within "Updates beschikbaar", the app installed longest ago is listed '
    'first',
    (tester) async {
      final library = _githubLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      // Both stay outdated relative to the mocked 2.0.0 release, but
      // StaleApp's installedVersion (and so lastInstalledAt) was recorded
      // first, making it the more neglected of the two.
      final staleApp = await library.addCustomApp(
        name: 'StaleApp',
        type: AppSourceType.github,
        source: 'owner/stale',
      );
      await library.markInstalled(staleApp.id, '1.0.0');
      final recentApp = await library.addCustomApp(
        name: 'RecentApp',
        type: AppSourceType.github,
        source: 'owner/recent',
      );
      await library.markInstalled(recentApp.id, '1.0.0');
      await library.checkAll();

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      final staleTile = tester.getCenter(find.text('StaleApp'));
      final recentTile = tester.getCenter(find.text('RecentApp'));
      expect(staleTile.dy, lessThan(recentTile.dy));
    },
  );

  testWidgets(
    'shows a one-line changelog preview under an updatable app in "Updates '
    'beschikbaar"',
    (tester) async {
      final library = _githubLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );

      await tester.pumpWidget(_wrap(HomeScreen(library: library)));
      await tester.pumpAndSettle();

      expect(find.text('Fixed a crash on startup.'), findsOneWidget);
    },
  );
}
