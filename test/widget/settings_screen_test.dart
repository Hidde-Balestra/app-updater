import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/settings_screen.dart';
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

import '../support/fake_background_scheduler.dart';
import '../support/fake_curated_apps.dart';
import '../support/mock_clipboard.dart';

SettingsController _settings() =>
    SettingsController(scheduler: FakeBackgroundScheduler());

AppLibrary _offlineLibrary() {
  final client = MockClient((request) async => http.Response('', 503));
  return AppLibrary(
    resolver: ReleaseResolver(
      github: GithubService(client: client),
      fdroid: FdroidService(client: client),
    ),
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
    MockClipboard().install();
  });

  testWidgets('toggling dark mode switch updates the settings controller', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();
    expect(settings.themeMode, ThemeMode.system);
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(
      _wrap(SettingsScreen(settings: settings, library: library)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Donkere modus'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('picking a language in the language sheet updates the locale', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();
    expect(settings.locale, isNull);
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(
      _wrap(SettingsScreen(settings: settings, library: library)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kies de taal van de app'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Engels').last);
    await tester.pumpAndSettle();

    expect(settings.locale, const Locale('en'));
  });

  testWidgets('toggling auto-check switch updates the settings controller', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();
    expect(settings.autoCheckEnabled, isTrue);
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(
      _wrap(SettingsScreen(settings: settings, library: library)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Automatisch controleren'),
    );
    await tester.pumpAndSettle();

    expect(settings.autoCheckEnabled, isFalse);
  });

  testWidgets('exporting to clipboard shows a confirmation snackbar', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();
    final library = _offlineLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'MijnBudget',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnbudget.apk',
    );

    await tester.pumpWidget(
      _wrap(SettingsScreen(settings: settings, library: library)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exporteren naar klembord'));
    await tester.pumpAndSettle();

    expect(find.text('1 apps naar klembord gekopieerd'), findsOneWidget);
  });
}
