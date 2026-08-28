import 'dart:convert';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/installed_app.dart';
import 'package:app_updater/screens/add_app_screen.dart';
import 'package:app_updater/services/device_apps_service.dart';
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
  _FakeDeviceAppsService(this.apps);

  @override
  Future<List<InstalledApp>> installedApps() async => apps;
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
}
