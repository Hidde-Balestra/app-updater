import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/update_history_screen.dart';
import 'package:app_updater/services/apk_installer_service.dart';
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

import '../support/fake_apk_installer_service.dart';
import '../support/fake_curated_apps.dart';
import '../support/fake_signing_service.dart';

// addCustomApp() calls installedVersion() for every app with a package
// name — a real DeviceAppsService falls through to the installed_apps
// platform channel, which flutter_test doesn't mock by default and which
// hangs rather than failing fast when unmocked under testWidgets.
class _FakeDeviceAppsService extends DeviceAppsService {
  @override
  Future<String?> installedVersion(String packageName) async => null;
}

AppLibrary _offlineLibrary({ApkInstallerService? installer}) {
  final client = MockClient((request) async => http.Response('', 503));
  return AppLibrary(
    resolver: ReleaseResolver(
      github: GithubService(client: client),
      fdroid: FdroidService(client: client),
    ),
    deviceApps: _FakeDeviceAppsService(),
    installer: installer,
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

  testWidgets('shows the empty message when nothing has been installed yet', (
    tester,
  ) async {
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(UpdateHistoryScreen(library: library)));
    await tester.pumpAndSettle();

    expect(
      find.text('Nog geen updates geïnstalleerd via App Updater.'),
      findsOneWidget,
    );
  });

  testWidgets('lists an installed app with its from/to versions', (
    tester,
  ) async {
    final installer = FakeApkInstallerService();
    final library = _offlineLibrary(installer: installer);
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnapp.apk',
      packageName: 'com.example.mijnapp',
    );
    await library.markInstalled(app.id, '1.0.0');
    await library.downloadAndInstall(app.id);

    await tester.pumpWidget(_wrap(UpdateHistoryScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('MijnApp'), findsOneWidget);
    final toVersion = library.entries.single.app.installedVersion!;
    expect(find.text('1.0.0 → $toVersion'), findsOneWidget);
  });
}
