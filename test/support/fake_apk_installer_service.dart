import 'package:app_updater/services/apk_installer_service.dart';

/// Records installed paths instead of touching the filesystem or the real
/// system package installer. `sha256Of` returns a fixed, obviously-fake
/// value so tests can assert on it without hashing anything for real.
class FakeApkInstallerService extends ApkInstallerService {
  final List<String> installedPaths = [];

  @override
  Future<String> downloadApk({
    required String url,
    required String fileName,
    void Function(int received, int? total)? onProgress,
  }) async {
    onProgress?.call(1, 1);
    return '/tmp/$fileName';
  }

  @override
  Future<String> sha256Of(String filePath) async => 'deadbeef';

  @override
  Future<void> installApk(String filePath) async {
    installedPaths.add(filePath);
  }
}
