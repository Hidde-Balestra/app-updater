import 'dart:convert';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/app_detail_screen.dart';
import 'package:app_updater/services/accrescent/accrescent_service.dart';
import 'package:app_updater/services/accrescent/generated/accrescent_appstore.pbgrpc.dart';
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

class _FakeAccrescentService extends AccrescentService {
  final String versionName;
  _FakeAccrescentService(this.versionName);

  @override
  Future<GetAppPackageInfoResponse> getPackageInfo(String appId) async =>
      GetAppPackageInfoResponse(
        packageInfo: PackageInfo(versionName: versionName),
      );
}

/// A library whose GitHub source always resolves to version 2.0.0.
AppLibrary _githubLibrary() {
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

  testWidgets(
    'tapping "skip this version" hides the update and shows the skipped '
    'banner',
    (tester) async {
      final library = _githubLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );
      await library.markInstalled(app.id, '1.0.0');
      await library.checkOne(app.id);

      await tester.pumpWidget(
        _wrap(AppDetailScreen(library: library, appId: app.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deze versie overslaan'), findsOneWidget);

      await tester.tap(find.text('Deze versie overslaan'));
      await tester.pumpAndSettle();

      expect(find.text('Versie 2.0.0 wordt overgeslagen'), findsOneWidget);
      expect(library.entries.single.app.skippedVersion, '2.0.0');
    },
  );

  testWidgets(
    'tapping "undo skip" on a skipped app restores the update-available '
    'state',
    (tester) async {
      final library = _githubLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );
      await library.markInstalled(app.id, '1.0.0');
      await library.checkOne(app.id);
      await library.skipVersion(app.id, '2.0.0');

      await tester.pumpWidget(
        _wrap(AppDetailScreen(library: library, appId: app.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Versie 2.0.0 wordt overgeslagen'), findsOneWidget);

      await tester.tap(find.text('Overslaan ongedaan maken'));
      await tester.pumpAndSettle();

      expect(find.text('Deze versie overslaan'), findsOneWidget);
      expect(library.entries.single.app.skippedVersion, isNull);
    },
  );

  testWidgets('shows "open in Accrescent" instead of a download button for an '
      'Accrescent-sourced app', (tester) async {
    final library = AppLibrary(
      resolver: ReleaseResolver(
        github: GithubService(
          client: MockClient((r) async => http.Response('', 503)),
        ),
        fdroid: FdroidService(
          client: MockClient((r) async => http.Response('', 503)),
        ),
        accrescent: _FakeAccrescentService('2026.07.23-6-Google'),
      ),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'Organic Maps',
      type: AppSourceType.accrescent,
      source: 'app.organicmaps',
    );

    await tester.pumpWidget(
      _wrap(AppDetailScreen(library: library, appId: app.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Openen in Accrescent'), findsOneWidget);
    expect(find.text('Download & installeer APK'), findsNothing);
  });
}
