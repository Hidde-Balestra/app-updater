import 'package:app_updater/services/fdroid_service.dart';
import 'package:app_updater/services/github_service.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:app_updater/state/app_library.dart';
import 'package:app_updater/state/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_apk_installer_service.dart';

// A resolver whose network calls always fail fast, so these tests stay
// hermetic (no real HTTP requests from a unit test).
ReleaseResolver _offlineResolver() {
  final client = MockClient((request) async => http.Response('', 503));
  return ReleaseResolver(
    github: GithubService(client: client),
    fdroid: FdroidService(client: client),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() adds bytes freed by cleanup to totalBytesCleanedUp and persists '
      'them', () async {
    final installer = FakeApkInstallerService()
      ..cleanUpOldDownloadsResult = 1234;
    final library = AppLibrary(
      resolver: _offlineResolver(),
      installer: installer,
    );

    await library.load();
    // cleanUpOldDownloads runs unawaited inside load(); give it a tick to
    // complete before asserting on its effect.
    await Future<void>.delayed(Duration.zero);

    expect(library.totalBytesCleanedUp, 1234);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(StorageKeys.cleanedUpBytes), 1234);
  });

  test(
    'load() leaves totalBytesCleanedUp untouched when nothing was cleaned up',
    () async {
      final installer = FakeApkInstallerService()
        ..cleanUpOldDownloadsResult = 0;
      final library = AppLibrary(
        resolver: _offlineResolver(),
        installer: installer,
      );

      await library.load();
      await Future<void>.delayed(Duration.zero);

      expect(library.totalBytesCleanedUp, 0);
    },
  );

  test('load() restores a previously persisted total', () async {
    SharedPreferences.setMockInitialValues({StorageKeys.cleanedUpBytes: 5000});
    final installer = FakeApkInstallerService()..cleanUpOldDownloadsResult = 0;
    final library = AppLibrary(
      resolver: _offlineResolver(),
      installer: installer,
    );

    await library.load();

    expect(library.totalBytesCleanedUp, 5000);
  });

  test('successive cleanups accumulate rather than overwrite', () async {
    SharedPreferences.setMockInitialValues({StorageKeys.cleanedUpBytes: 1000});
    final installer = FakeApkInstallerService()
      ..cleanUpOldDownloadsResult = 500;
    final library = AppLibrary(
      resolver: _offlineResolver(),
      installer: installer,
    );

    await library.load();
    await Future<void>.delayed(Duration.zero);

    expect(library.totalBytesCleanedUp, 1500);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(StorageKeys.cleanedUpBytes), 1500);
  });
}
