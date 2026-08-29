import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isUpdateAvailable', () {
    test('true when nothing installed yet', () {
      expect(
        isUpdateAvailable(installedVersion: null, latestVersion: '1.0.0'),
        isTrue,
      );
    });

    test('true when installed and latest differ', () {
      expect(
        isUpdateAvailable(installedVersion: '1.4.0', latestVersion: '1.5.0'),
        isTrue,
      );
    });

    test('false when installed and latest match', () {
      expect(
        isUpdateAvailable(installedVersion: '1.5.0', latestVersion: '1.5.0'),
        isFalse,
      );
    });

    test('false when latest version is unknown', () {
      expect(
        isUpdateAvailable(installedVersion: '1.5.0', latestVersion: null),
        isFalse,
      );
    });

    test('does not attempt semver ordering, only inequality', () {
      // A non-semver tag like "V.0.8.0" must still be treated as an update
      // relative to a differently-formatted installed version.
      expect(
        isUpdateAvailable(installedVersion: '0.7.0', latestVersion: 'V.0.8.0'),
        isTrue,
      );
    });

    test('false when only a leading v/V prefix differs (same release)', () {
      // Seen in practice: Android's own versionName kept the "v" (as
      // recorded by a device scan) while GithubService strips it from the
      // release tag before storing it.
      expect(
        isUpdateAvailable(
          installedVersion: 'v8.19.2-4',
          latestVersion: '8.19.2-4',
        ),
        isFalse,
      );
      expect(
        isUpdateAvailable(
          installedVersion: '8.19.2-4',
          latestVersion: 'v8.19.2-4',
        ),
        isFalse,
      );
      expect(
        isUpdateAvailable(installedVersion: 'V1.2.3', latestVersion: '1.2.3'),
        isFalse,
      );
    });

    test('still an update when versions differ beyond just the v prefix', () {
      expect(
        isUpdateAvailable(
          installedVersion: 'v8.19.2-3',
          latestVersion: '8.19.2-4',
        ),
        isTrue,
      );
    });

    test('does not strip a leading v/V that is not followed by a digit', () {
      // Guards against mangling a version string that merely starts with
      // the letter v/V for some other reason.
      expect(
        isUpdateAvailable(installedVersion: 'variant-1', latestVersion: '1'),
        isTrue,
      );
    });
  });

  group('appHasUpdate', () {
    test('direct sources only look at whether anything is installed', () {
      expect(
        appHasUpdate(
          sourceType: AppSourceType.direct,
          installedVersion: null,
          latestVersion: '',
        ),
        isTrue,
      );
      expect(
        appHasUpdate(
          sourceType: AppSourceType.direct,
          installedVersion: '2024-01-01',
          latestVersion: '',
        ),
        isFalse,
      );
    });

    test('github/fdroid sources defer to isUpdateAvailable', () {
      expect(
        appHasUpdate(
          sourceType: AppSourceType.github,
          installedVersion: '1.0.0',
          latestVersion: '1.1.0',
        ),
        isTrue,
      );
      expect(
        appHasUpdate(
          sourceType: AppSourceType.fdroid,
          installedVersion: '1.1.0',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
    });
  });

  group('isVersionSkipped', () {
    test('true when the latest version exactly matches the skipped one', () {
      expect(
        isVersionSkipped(skippedVersion: '1.1.0', latestVersion: '1.1.0'),
        isTrue,
      );
    });

    test('false once a newer release appears', () {
      expect(
        isVersionSkipped(skippedVersion: '1.1.0', latestVersion: '1.2.0'),
        isFalse,
      );
    });

    test('false when nothing has been skipped', () {
      expect(
        isVersionSkipped(skippedVersion: null, latestVersion: '1.1.0'),
        isFalse,
      );
    });

    test('false when the latest version is unknown', () {
      expect(
        isVersionSkipped(skippedVersion: '1.1.0', latestVersion: null),
        isFalse,
      );
    });
  });
}
