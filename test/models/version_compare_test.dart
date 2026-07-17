import 'package:app_updater/models/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isUpdateAvailable', () {
    test('true when nothing installed yet', () {
      expect(isUpdateAvailable(installedVersion: null, latestVersion: '1.0.0'), isTrue);
    });

    test('true when installed and latest differ', () {
      expect(isUpdateAvailable(installedVersion: '1.4.0', latestVersion: '1.5.0'), isTrue);
    });

    test('false when installed and latest match', () {
      expect(isUpdateAvailable(installedVersion: '1.5.0', latestVersion: '1.5.0'), isFalse);
    });

    test('false when latest version is unknown', () {
      expect(isUpdateAvailable(installedVersion: '1.5.0', latestVersion: null), isFalse);
    });

    test('does not attempt semver ordering, only inequality', () {
      // A non-semver tag like "V.0.8.0" must still be treated as an update
      // relative to a differently-formatted installed version.
      expect(isUpdateAvailable(installedVersion: '0.7.0', latestVersion: 'V.0.8.0'), isTrue);
    });
  });
}
