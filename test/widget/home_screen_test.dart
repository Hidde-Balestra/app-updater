import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/home_screen.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  testWidgets('shows the empty state when there are no tracked apps', (tester) async {
    final library = _offlineLibrary();
    await library.load();

    await tester.pumpWidget(_wrap(HomeScreen(library: library)));
    await tester.pumpAndSettle();

    expect(find.text('Nog geen apps'), findsOneWidget);
  });

  testWidgets('renders a custom app under "Mijn apps" and a favorite under "Favoriete apps"', (
    tester,
  ) async {
    final library = _offlineLibrary();
    await library.load();
    await library.addCustomApp(
      name: 'MijnBudget',
      type: AppSourceType.direct,
      source: 'https://example.com/mijnbudget.apk',
    );
    await library.addFavorite(library.curatedApps.first);

    await tester.pumpWidget(_wrap(HomeScreen(library: library)));
    await tester.pumpAndSettle();

    // SectionHeader renders titles upper-cased.
    expect(find.text('MIJN APPS'), findsOneWidget);
    expect(find.text('MijnBudget'), findsOneWidget);
    expect(find.text('FAVORIETE APPS'), findsOneWidget);
    expect(find.text(library.curatedApps.first.name), findsOneWidget);
  });
}
