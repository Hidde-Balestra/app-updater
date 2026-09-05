import 'dart:convert';
import 'dart:typed_data';

import 'package:app_updater/l10n/app_localizations.dart';
import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/screens/app_detail_screen.dart';
import 'package:app_updater/services/accrescent/accrescent_service.dart';
import 'package:app_updater/services/accrescent/generated/accrescent_appstore.pbgrpc.dart';
import 'package:app_updater/services/apk_installer_service.dart';
import 'package:app_updater/services/device_apps_service.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/services/signing_service.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_apk_installer_service.dart';
import '../support/fake_curated_apps.dart';
import '../support/fake_signing_service.dart';

class _FakeAccrescentService extends AccrescentService {
  final String versionName;
  _FakeAccrescentService(this.versionName);

  @override
  Future<GetAppPackageInfoResponse> getPackageInfo(String appId) async =>
      GetAppPackageInfoResponse(
        packageInfo: PackageInfo(versionName: versionName),
      );
}

// addCustomApp() calls installedVersion() for every app with a package
// name — a real DeviceAppsService falls through to the installed_apps
// platform channel, which flutter_test doesn't mock by default and which
// hangs rather than failing fast when unmocked under testWidgets.
class _FakeDeviceAppsService extends DeviceAppsService {
  final Uint8List? icon;
  _FakeDeviceAppsService({this.icon});

  @override
  Future<String?> installedVersion(String packageName) async => null;

  @override
  Future<Uint8List?> installedIcon(String packageName) async => icon;
}

/// A library whose GitHub source always resolves to version 2.0.0.
AppLibrary _githubLibrary({
  ApkInstallerService? installer,
  SigningService? signing,
  DeviceAppsService? deviceApps,
}) {
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
    deviceApps: deviceApps ?? _FakeDeviceAppsService(),
    installer: installer,
    signing: signing,
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

  testWidgets(
    'tapping "download & install" with a signing mismatch shows a warning '
    'dialog, and confirming installs anyway',
    (tester) async {
      final installer = FakeApkInstallerService();
      final library = _githubLibrary(
        installer: installer,
        signing: FakeSigningService(
          installedHashes: {'aaa'},
          apkHashes: {'bbb'},
        ),
      );
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
        packageName: 'com.example.mijnapp',
      );

      await tester.pumpWidget(
        _wrap(AppDetailScreen(library: library, appId: app.id)),
      );
      await tester.pumpAndSettle();

      // Not pumpAndSettle(): the "installing…" button keeps an indeterminate
      // CircularProgressIndicator animating for as long as the confirmation
      // dialog (awaited inside downloadAndInstall) is up, which
      // pumpAndSettle can never consider "settled".
      await tester.tap(find.text('Download & installeer APK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Andere ondertekening gedetecteerd'), findsOneWidget);

      await tester.tap(find.text('Toch installeren'));
      await tester.pumpAndSettle();

      expect(installer.installedPaths, hasLength(1));
    },
  );

  testWidgets('shows when the app was last checked', (tester) async {
    final library = _githubLibrary();
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
    );

    await tester.pumpWidget(
      _wrap(AppDetailScreen(library: library, appId: app.id)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Laatst gecontroleerd:'), findsOneWidget);
  });

  testWidgets('tapping the check-now button re-checks the app', (tester) async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
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
    });
    final library = AppLibrary(
      resolver: ReleaseResolver(
        github: GithubService(client: client),
        fdroid: FdroidService(
          client: MockClient((r) async => http.Response('', 503)),
        ),
      ),
      deviceApps: _FakeDeviceAppsService(),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
    );

    await tester.pumpWidget(
      _wrap(AppDetailScreen(library: library, appId: app.id)),
    );
    await tester.pumpAndSettle();

    final requestsBeforeTap = requestCount;
    await tester.tap(find.byTooltip('Nu controleren'));
    await tester.pumpAndSettle();

    expect(requestCount, requestsBeforeTap + 1);
  });

  testWidgets('shows the app\'s real icon when it is installed on the '
      'device', (tester) async {
    // A minimal valid 1x1 transparent PNG, so Image.memory can actually
    // decode it instead of erroring out on garbage bytes.
    final iconBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42'
        'YAAAAASUVORK5CYII=',
      ),
    );
    final library = _githubLibrary(
      deviceApps: _FakeDeviceAppsService(icon: iconBytes),
    );
    await library.load(curatedAppsOverride: testCuratedApps);
    final app = await library.addCustomApp(
      name: 'MijnApp',
      type: AppSourceType.github,
      source: 'owner/repo',
      packageName: 'com.example.mijnapp',
    );

    await tester.pumpWidget(
      _wrap(AppDetailScreen(library: library, appId: app.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(AppAvatar), findsNothing);
  });

  testWidgets(
    'falls back to the colored-initials avatar when there is no package '
    'name to look up an icon for',
    (tester) async {
      final library = _githubLibrary();
      await library.load(curatedAppsOverride: testCuratedApps);
      final app = await library.addCustomApp(
        name: 'MijnApp',
        type: AppSourceType.github,
        source: 'owner/repo',
      );

      await tester.pumpWidget(
        _wrap(AppDetailScreen(library: library, appId: app.id)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppAvatar), findsWidgets);
      expect(find.byType(Image), findsNothing);
    },
  );
}
