import 'package:app_updater/services/signing_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_updater/signing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('apkCertificateHashes returns the hashes from the platform', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'apkCertificateHashes');
      expect(call.arguments, {'path': '/tmp/app.apk'});
      return ['aaa', 'bbb'];
    });

    final hashes = await SigningService().apkCertificateHashes('/tmp/app.apk');

    expect(hashes, {'aaa', 'bbb'});
  });

  test(
    'installedCertificateHashes returns the hashes from the platform',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'installedCertificateHashes');
        expect(call.arguments, {'packageName': 'com.example.app'});
        return ['ccc'];
      });

      final hashes = await SigningService().installedCertificateHashes(
        'com.example.app',
      );

      expect(hashes, {'ccc'});
    },
  );

  test(
    'installedCertificateHashes returns empty when nothing is installed',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => <String>[]);

      final hashes = await SigningService().installedCertificateHashes(
        'com.example.notinstalled',
      );

      expect(hashes, isEmpty);
    },
  );

  test('returns empty instead of throwing when the platform errors', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    final apkHashes = await SigningService().apkCertificateHashes(
      '/tmp/app.apk',
    );
    final installedHashes = await SigningService().installedCertificateHashes(
      'com.example.app',
    );

    expect(apkHashes, isEmpty);
    expect(installedHashes, isEmpty);
  });
}
