import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/screens/home_shell.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the Apps tab and can switch to Instellingen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final client = MockClient((request) async => http.Response('', 503));
    final library = AppLibrary(
      resolver: ReleaseResolver(
        github: GithubService(client: client),
        fdroid: FdroidService(client: client),
      ),
    );
    final settings = SettingsController();
    await library.load();
    await settings.load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeShell(library: library, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Updater'), findsOneWidget);

    await tester.tap(find.text('Instellingen'));
    await tester.pumpAndSettle();

    expect(find.text('Donkere modus'), findsOneWidget);
  });
}
