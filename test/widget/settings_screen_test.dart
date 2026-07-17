import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/screens/settings_screen.dart';
import 'package:app_updater/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('toggling dark mode switch updates the settings controller', (tester) async {
    final settings = SettingsController();
    await settings.load();
    expect(settings.themeMode, ThemeMode.system);

    await tester.pumpWidget(_wrap(SettingsScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Donkere modus'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('picking a language in the language sheet updates the locale', (tester) async {
    final settings = SettingsController();
    await settings.load();
    expect(settings.locale, isNull);

    await tester.pumpWidget(_wrap(SettingsScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kies de taal van de app'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Engels').last);
    await tester.pumpAndSettle();

    expect(settings.locale, const Locale('en'));
  });

  testWidgets('toggling auto-check switch updates the settings controller', (tester) async {
    final settings = SettingsController();
    await settings.load();
    expect(settings.autoCheckEnabled, isTrue);

    await tester.pumpWidget(_wrap(SettingsScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Automatisch controleren'));
    await tester.pumpAndSettle();

    expect(settings.autoCheckEnabled, isFalse);
  });
}
