import 'dart:convert';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
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

import '../support/fake_background_scheduler.dart';
import '../support/fake_curated_apps.dart';

Widget _wrap(AppLibrary library) => MaterialApp(
  locale: const Locale('nl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: HomeShell(
    library: library,
    settings: SettingsController(scheduler: FakeBackgroundScheduler()),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hides the Apps-tab badge when nothing needs an update', (
    tester,
  ) async {
    final client = MockClient((request) async => http.Response('', 503));
    final library = AppLibrary(
      resolver: ReleaseResolver(
        github: GithubService(client: client),
        fdroid: FdroidService(client: client),
      ),
    );
    await library.load(curatedAppsOverride: testCuratedApps);

    await tester.pumpWidget(_wrap(library));
    await tester.pumpAndSettle();

    final badges = tester.widgetList<Badge>(find.byType(Badge));
    expect(badges, isNotEmpty);
    expect(badges.every((b) => b.isLabelVisible == false), isTrue);
  });

  testWidgets('shows the update count as a badge on the Apps tab', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
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
    final library = AppLibrary(
      resolver: ReleaseResolver(
        github: GithubService(client: client),
        fdroid: FdroidService(client: client),
      ),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
    );

    await tester.pumpWidget(_wrap(library));
    await tester.pumpAndSettle();

    final visibleBadges = tester
        .widgetList<Badge>(find.byType(Badge))
        .where((b) => b.isLabelVisible == true);
    expect(visibleBadges, isNotEmpty);
    expect(find.text('1'), findsWidgets);
  });
}
