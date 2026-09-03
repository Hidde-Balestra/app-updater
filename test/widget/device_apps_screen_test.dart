import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/installed_app.dart';
import 'package:app_updater/screens/device_apps_screen.dart';
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

  // addCustomApp() also calls installedVersion() for every app with a
  // package name — override it so that never falls through to the real
  // installed_apps platform channel, which flutter_test doesn't mock by
  // default and which hangs rather than failing fast when unmocked under
  // testWidgets.
  @override
  Future<String?> installedVersion(String packageName) async => null;
}

AppLibrary _offlineLibrary(List<InstalledApp> installed) {
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

  testWidgets('shows the empty message when the device has no apps', (
    tester,
  ) async {
    final library = _offlineLibrary(const []);
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(DeviceAppsScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('Geen apps gevonden op je toestel.'), findsOneWidget);
  });

  testWidgets('shows the right status and actions per app', (tester) async {
    final library = _offlineLibrary(const [
      InstalledApp(
        name: 'TrackedApp',
        packageName: 'com.example.tracked',
        versionName: '1.0.0',
      ),
      InstalledApp(
        name: 'AvailableApp',
        packageName: 'com.example.available',
        versionName: '1.0.0',
      ),
    ]);
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'TrackedApp',
      type: AppSourceType.direct,
      source: 'https://example.com/tracked.apk',
      packageName: 'com.example.tracked',
    );

    await tester.pumpWidget(_wrap(DeviceAppsScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('Al getrackt'), findsOneWidget);
    expect(find.text('Gebruiken'), findsOneWidget);
    expect(find.text('Negeren'), findsOneWidget);
  });

  testWidgets('tapping negeren switches the app to ignored, with a restore '
      'button', (tester) async {
    final library = _offlineLibrary(const [
      InstalledApp(
        name: 'AvailableApp',
        packageName: 'com.example.available',
        versionName: '1.0.0',
      ),
    ]);
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(DeviceAppsScreen(library: library)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Negeren'));
    await tester.pumpAndSettle();

    expect(find.text('Genegeerd'), findsOneWidget);
    expect(find.text('Terugzetten'), findsOneWidget);
    expect(find.text('Negeren'), findsNothing);
    expect(library.ignoredPackageNames, {'com.example.available'});
  });
}
