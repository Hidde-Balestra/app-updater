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

  group('ApkInstallerService.cleanUpOldDownloads', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('apk_cleanup_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Backdates [path]'s modified time so it looks like it was downloaded
    /// [age] ago, without needing a real wall-clock wait in the test.
    void writeApk(String path, {required Duration age}) {
      File(path).writeAsBytesSync([1, 2, 3]);
      File(path).setLastModifiedSync(DateTime.now().subtract(age));
    }

    test('deletes an .apk older than minAge', () async {
      final path = '${tempDir.path}/old.apk';
      writeApk(path, age: const Duration(minutes: 20));

      await ApkInstallerService().cleanUpOldDownloads(
        minAge: const Duration(minutes: 10),
        directory: tempDir,
      );

      expect(File(path).existsSync(), isFalse);
    });

    test('leaves an .apk newer than minAge untouched', () async {
      final path = '${tempDir.path}/fresh.apk';
      writeApk(path, age: const Duration(minutes: 1));

      await ApkInstallerService().cleanUpOldDownloads(
        minAge: const Duration(minutes: 10),
        directory: tempDir,
      );

      expect(File(path).existsSync(), isTrue);
    });

    test('leaves non-.apk files untouched regardless of age', () async {
      final path = '${tempDir.path}/notes.txt';
      writeApk(path, age: const Duration(days: 1));

      await ApkInstallerService().cleanUpOldDownloads(
        minAge: const Duration(minutes: 10),
        directory: tempDir,
      );

      expect(File(path).existsSync(), isTrue);
    });

    test('does nothing when the directory does not exist', () async {
      final missing = Directory('${tempDir.path}/does-not-exist');

      await expectLater(
        ApkInstallerService().cleanUpOldDownloads(directory: missing),
        completes,
      );
    });
  });
}
