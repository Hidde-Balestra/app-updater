import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/screens/access_tokens_screen.dart';
import 'package:app_updater/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_background_scheduler.dart';

SettingsController _settings() =>
    SettingsController(scheduler: FakeBackgroundScheduler());

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('nl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('shows all three token rows as not set by default', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();

    await tester.pumpWidget(_wrap(AccessTokensScreen(settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('GitHub-token'), findsOneWidget);
    expect(find.text('GitLab-token'), findsOneWidget);
    expect(find.text('Codeberg-token'), findsOneWidget);
    expect(
      find.text(
        'Niet ingesteld — checks kunnen tegen de limiet van GitHub aanlopen',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Niet ingesteld — checks kunnen tegen de limiet van GitLab aanlopen',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Niet ingesteld — checks kunnen tegen de limiet van Codeberg aanlopen',
      ),
      findsOneWidget,
    );
  });

  testWidgets('entering a Codeberg token in the dialog saves it', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();

    await tester.pumpWidget(_wrap(AccessTokensScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Codeberg-token'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'codeberg-abc123');
    await tester.tap(find.text('Opslaan'));
    await tester.pumpAndSettle();

    expect(settings.codebergToken, 'codeberg-abc123');
    expect(find.text('Ingesteld'), findsOneWidget);
  });

  testWidgets('cancelling the dialog leaves the token untouched', (
    tester,
  ) async {
    final settings = _settings();
    await settings.load();

    await tester.pumpWidget(_wrap(AccessTokensScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub-token'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ghp_shouldnotsave');
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    expect(settings.githubToken, isNull);
  });
}
