import 'package:app_updater/services/signing_service.dart';

/// Returns empty hash sets for everything (i.e. "nothing to compare, no
/// mismatch") without touching the real platform channel, so tests that
/// exercise [AppLibrary.downloadAndInstall] stay hermetic and don't
/// incidentally depend on how an unmocked MethodChannel behaves in the test
/// environment. Tests that specifically want to exercise a signing mismatch
/// should override the two methods directly instead.
class FakeSigningService extends SigningService {
  final Set<String> installedHashes;
  final Set<String> apkHashes;

  FakeSigningService({
    this.installedHashes = const {},
    this.apkHashes = const {},
  });

  @override
  Future<Set<String>> installedCertificateHashes(String packageName) async =>
      installedHashes;

  @override
  Future<Set<String>> apkCertificateHashes(String apkPath) async => apkHashes;
}
