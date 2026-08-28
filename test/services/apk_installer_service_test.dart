import 'dart:io';

import 'package:app_updater/services/apk_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApkInstallerService.sha256Of', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('apk_installer_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('matches the known digest for a small file', () async {
      final file = File('${tempDir.path}/abc.txt')..writeAsStringSync('abc');

      final hash = await ApkInstallerService().sha256Of(file.path);

      expect(
        hash,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('matches the known digest for an empty file', () async {
      final file = File('${tempDir.path}/empty.txt')
        ..writeAsBytesSync(const []);

      final hash = await ApkInstallerService().sha256Of(file.path);

      expect(
        hash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });
}
