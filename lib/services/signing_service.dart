import 'package:flutter/services.dart';

/// Reads APK/installed-app signing certificate hashes via a native
/// MethodChannel (see MainActivity.kt), so [AppLibrary] can warn before
/// installing a download signed with a different key than what's already on
/// the device. Every method is best-effort: an empty set means either "no
/// signing info available" or "not applicable" (e.g. pre-API-28 device, or
/// the app isn't installed yet) — never a thrown exception, since a
/// verification-infrastructure hiccup must not block a normal install.
class SigningService {
  static const _channel = MethodChannel('app_updater/signing');

  /// SHA-256 hashes (hex-encoded) of the signing certificate(s) that would
  /// sign the running app at [apkPath] if it were installed.
  Future<Set<String>> apkCertificateHashes(String apkPath) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'apkCertificateHashes',
        {'path': apkPath},
      );
      return (result ?? const []).cast<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  /// SHA-256 hashes (hex-encoded) of the signing certificate(s) of the
  /// currently-installed app with [packageName]. Empty when nothing is
  /// installed under that package name.
  Future<Set<String>> installedCertificateHashes(String packageName) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'installedCertificateHashes',
        {'packageName': packageName},
      );
      return (result ?? const []).cast<String>().toSet();
    } catch (_) {
      return const {};
    }
  }
}
