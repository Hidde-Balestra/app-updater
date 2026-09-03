import 'dart:convert';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/installed_app.dart';
import 'package:app_updater/screens/add_app_screen.dart';
import 'package:app_updater/services/device_apps_service.dart';
import 'package:app_updater/services/fdroid_search_service.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_curated_apps.dart';

class _FakeDeviceAppsService extends DeviceAppsService {
  final List<InstalledApp> apps;
  final Map<String, String> versionsByPackage;
  _FakeDeviceAppsService(this.apps, {this.versionsByPackage = const {}});

  @override
  Future<List<InstalledApp>> installedApps() async => apps;

  @override
  Future<String?> installedVersion(String packageName) async =>
      versionsByPackage[packageName];
}

AppLibrary _offlineLibrary({List<InstalledApp> installed = const []}) {
  final client = MockClient((request) async => http.Response('', 503));
  return AppLibrary(
    resolver: ReleaseResolver(
      github: GithubService(client: client),
      fdroid: FdroidService(client: client),
    ),
    deviceApps: _FakeDeviceAppsService(installed),
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

  testWidgets('shows the empty message when no device apps are found', (
    tester,
  ) async {
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Van toestel'));
    await tester.pumpAndSettle();

    expect(
      find.text('Geen nieuwe apps gevonden op je toestel.'),
      findsOneWidget,
    );
  });

  testWidgets('lists installed apps not already tracked', (tester) async {
    final library = _offlineLibrary(
      installed: const [
        InstalledApp(
          name: 'MijnBudget',
          packageName: 'com.example.mijnbudget',
          versionName: '1.2.0',
        ),
      ],
    );
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Van toestel'));
    await tester.pumpAndSettle();

    expect(find.text('MijnBudget'), findsOneWidget);
    expect(find.text('com.example.mijnbudget'), findsOneWidget);
  });

  testWidgets(
    'using an installed app prefills the custom-app tab and switches to it',
    (tester) async {
      final library = _offlineLibrary(
        installed: const [
          InstalledApp(
            name: 'MijnBudget',
            packageName: 'com.example.mijnbudget',
            versionName: '1.2.0',
          ),
        ],
      );
      await library.load(curatedAppsOverride: testCuratedApps);

      await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Van toestel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gebruiken'));
      await tester.pumpAndSettle();

      expect(find.text('MijnBudget'), findsOneWidget);
      // Appears twice: the package-name field, and the source field (which
      // now also gets prefilled to drive the automatic F-Droid lookup).
      expect(find.text('com.example.mijnbudget'), findsNWidgets(2));
      expect(
        find.text('Kies nu een bron om MijnBudget te kunnen volgen.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'using an installed app auto-resolves it via F-Droid when the exact '
    'package is found there',
    (tester) async {
      final fdroidClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://f-droid.org/api/v1/packages/com.example.mijnbudget',
        );
        return http.Response(
          jsonEncode({
            'packageName': 'com.example.mijnbudget',
            'suggestedVersionCode': 3,
            'packages': [
              {'versionName': '3.4.0', 'versionCode': 3},
            ],
          }),
          200,
        );
      });
      final library = AppLibrary(
        resolver: ReleaseResolver(
          github: GithubService(
            client: MockClient((r) async => http.Response('', 503)),
          ),
          fdroid: FdroidService(client: fdroidClient),
        ),
        deviceApps: _FakeDeviceAppsService(const [
          InstalledApp(
            name: 'MijnBudget',
            packageName: 'com.example.mijnbudget',
            versionName: '1.2.0',
          ),
        ]),
      );
      await library.load(curatedAppsOverride: testCuratedApps);

      await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Van toestel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gebruiken'));
      await tester.pumpAndSettle();

      expect(
        find.text('Laatste release: 3.4.0 — gevonden via F-Droid'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows an F-Droid badge and a bulk-add banner for apps found there',
    (tester) async {
      final fdroidClient = MockClient((request) async {
        if (request.url.toString().endsWith('com.example.onfdroid')) {
          return http.Response(
            jsonEncode({
              'packageName': 'com.example.onfdroid',
              'suggestedVersionCode': 5,
              'packages': [
                {'versionName': '5.0', 'versionCode': 5},
              ],
            }),
            200,
          );
        }
        return http.Response('', 404);
      });
      final library = AppLibrary(
        resolver: ReleaseResolver(
          github: GithubService(
            client: MockClient((r) async => http.Response('', 503)),
          ),
          fdroid: FdroidService(client: fdroidClient),
        ),
        deviceApps: _FakeDeviceAppsService(const [
          InstalledApp(
            name: 'OnFdroid',
            packageName: 'com.example.onfdroid',
            versionName: '5.0',
          ),
          InstalledApp(
            name: 'NotOnFdroid',
            packageName: 'com.example.notonfdroid',
            versionName: '1.0',
          ),
        ]),
      );
      await library.load(curatedAppsOverride: testCuratedApps);

      await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Van toestel'));
      await tester.pumpAndSettle();

      expect(find.text('1 apps beschikbaar via F-Droid'), findsOneWidget);
      expect(find.text('Alles toevoegen'), findsOneWidget);
      // "F-Droid" also labels the new catalog tab, so scope the badge check
      // to the tile it's actually on rather than a bare find.text.
      final onFdroidTile = find.ancestor(
        of: find.text('OnFdroid'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: onFdroidTile, matching: find.text('F-Droid')),
        findsOneWidget,
      );

      await tester.tap(find.text('Alles toevoegen'));
      await tester.pumpAndSettle();

      expect(find.text('1 apps toegevoegd via F-Droid'), findsOneWidget);
      expect(library.entries.single.app.sourceType, AppSourceType.fdroid);
      expect(library.entries.single.app.packageName, 'com.example.onfdroid');
    },
  );

  testWidgets(
    'searching the F-Droid catalog tab lists results, and tapping add '
    'tracks the app via F-Droid',
    (tester) async {
      final fdroidClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'packageName': 'im.molly.app',
            'suggestedVersionCode': 1,
            'packages': [
              {'versionName': '8.0.0', 'versionCode': 1},
            ],
          }),
          200,
        );
      });
      final library = AppLibrary(
        resolver: ReleaseResolver(
          github: GithubService(
            client: MockClient((r) async => http.Response('', 503)),
          ),
          fdroid: FdroidService(client: fdroidClient),
        ),
        // Reported as already installed, so tapping "add" doesn't also
        // trigger a real download-and-install attempt through the add-app
        // screen's install-if-missing behavior — this test only cares
        // about tracking the app via F-Droid.
        deviceApps: _FakeDeviceAppsService(
          const [],
          versionsByPackage: const {'im.molly.app': '7.0.0'},
        ),
        fdroidSearch: FdroidSearchService(
          client: MockClient((request) async {
            expect(request.url.queryParameters['q'], 'molly');
            return http.Response(
              jsonEncode({
                'apps': [
                  {
                    'name': 'Molly',
                    'summary': 'Hardened Signal fork',
                    'url': 'https://f-droid.org/en/packages/im.molly.app',
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );
      await library.load(curatedAppsOverride: testCuratedApps);

      await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
      await tester.pumpAndSettle();

      // The custom-app tab's source-type selector also has an "F-Droid"
      // label, so tap the Tab specifically rather than a bare find.text.
      await tester.tap(find.widgetWithText(Tab, 'F-Droid'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Typ een naam om te zoeken in de volledige F-Droid catalogus.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('fdroidCatalogSearchField')),
        'molly',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Molly'), findsOneWidget);
      expect(find.text('Hardened Signal fork'), findsOneWidget);

      await tester.tap(find.text('Toevoegen'));
      await tester.pumpAndSettle();

      expect(find.text('Toegevoegd'), findsOneWidget);
      expect(library.entries.single.app.name, 'Molly');
      expect(library.entries.single.app.sourceType, AppSourceType.fdroid);
      expect(library.entries.single.app.packageName, 'im.molly.app');
    },
  );

  testWidgets(
    'shows an empty message when the F-Droid catalog search has no hits',
    (tester) async {
      final library = AppLibrary(
        resolver: ReleaseResolver(
          github: GithubService(
            client: MockClient((r) async => http.Response('', 503)),
          ),
          fdroid: FdroidService(
            client: MockClient((r) async => http.Response('', 503)),
          ),
        ),
        fdroidSearch: FdroidSearchService(
          client: MockClient(
            (request) async => http.Response(jsonEncode({'apps': []}), 200),
          ),
        ),
      );
      await library.load(curatedAppsOverride: testCuratedApps);

      await tester.pumpWidget(_wrap(AddAppScreen(library: library)));
      await tester.pumpAndSettle();

      // The custom-app tab's source-type selector also has an "F-Droid"
      // label, so tap the Tab specifically rather than a bare find.text.
      await tester.tap(find.widgetWithText(Tab, 'F-Droid'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('fdroidCatalogSearchField')),
        'nonexistentapp',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(
        find.text('Geen apps gevonden op F-Droid voor "nonexistentapp".'),
        findsOneWidget,
      );
    },
  );
}
