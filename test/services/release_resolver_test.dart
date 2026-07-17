import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/release_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReleaseResolver.resolveDirect', () {
    final resolver = ReleaseResolver();

    test('accepts a direct .apk URL with an empty version', () async {
      final result = await resolver.resolveDirect('https://f-droid.org/F-Droid.apk');
      expect(result, isA<ReleaseSuccess>());
      final info = (result as ReleaseSuccess).info;
      expect(info.version, isEmpty);
      expect(info.downloadUrl, 'https://f-droid.org/F-Droid.apk');
    });

    test('rejects a URL that does not point at an apk', () async {
      final result = await resolver.resolveDirect('https://example.com/app.zip');
      expect(result, isA<ReleaseError>());
    });

    test('rejects empty input', () async {
      final result = await resolver.resolveDirect('   ');
      expect(result, isA<ReleaseError>());
    });
  });
}
