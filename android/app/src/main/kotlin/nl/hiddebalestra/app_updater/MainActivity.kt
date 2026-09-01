package nl.hiddebalestra.app_updater

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

private const val SIGNING_CHANNEL = "app_updater/signing"

/**
 * Backs SigningService (lib/services/signing_service.dart): reads the
 * signing certificate(s) of a downloaded-but-not-yet-installed APK file and
 * of an already-installed app, so the Dart side can warn the user when a
 * new download is signed with a different key than what's currently
 * installed. Every failure path returns an empty list rather than throwing
 * across the channel — the Dart side treats "nothing to compare" as "don't
 * block the install", since this is a best-effort extra warning, not the
 * only thing standing between the user and a malicious APK (Android's own
 * installer already refuses a genuinely mismatched update on its own).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIGNING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkCertificateHashes" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path == null) emptyList<String>() else apkCertificateHashes(path))
                    }
                    "installedCertificateHashes" -> {
                        val packageName = call.argument<String>("packageName")
                        result.success(
                            if (packageName == null) emptyList<String>() else installedCertificateHashes(packageName)
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun apkCertificateHashes(path: String): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return emptyList()
        return try {
            val info = packageManager.getPackageArchiveInfo(path, PackageManager.GET_SIGNING_CERTIFICATES)
            if (info == null) emptyList() else hashesFromSigningInfo(info)
        } catch (e: Exception) {
            emptyList()
        }
    }

    @Suppress("DEPRECATION")
    private fun installedCertificateHashes(packageName: String): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return emptyList()
        return try {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            hashesFromSigningInfo(info)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun hashesFromSigningInfo(info: PackageInfo): List<String> {
        val signingInfo = info.signingInfo ?: return emptyList()
        val signatures = signingInfo.apkContentsSigners ?: return emptyList()
        val digest = MessageDigest.getInstance("SHA-256")
        return signatures.map { signature ->
            digest.digest(signature.toByteArray()).joinToString("") { byte -> "%02x".format(byte) }
        }
    }
}
