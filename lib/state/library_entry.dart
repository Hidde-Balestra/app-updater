import '../models/release_info.dart';
import '../models/tracked_app.dart';

enum AppCheckStatus {
  checking,
  upToDate,
  updateAvailable,
  error,
  noReleases,
  skipped,
}

/// A tracked app combined with its last-fetched release status. The status
/// itself is never persisted — it's re-derived from the network on every
/// check, only [TrackedApp.installedVersion] is saved to disk.
class LibraryEntry {
  final TrackedApp app;
  final AppCheckStatus status;
  final ReleaseInfo? latestRelease;
  final String? errorMessage;

  /// SHA-256 of the most recently downloaded APK for this app, for the user
  /// to cross-check against a hash published elsewhere. Never persisted —
  /// only relevant for the download that just happened this session.
  final String? lastDownloadSha256;

  /// When this app's source was last queried for a release, success or
  /// not — lets the detail screen show how fresh (or stale, if checks keep
  /// failing) the shown status actually is. Never persisted, like [status]:
  /// re-derived every time [AppLibrary.checkOne] runs this session.
  final DateTime? lastCheckedAt;

  const LibraryEntry({
    required this.app,
    required this.status,
    this.latestRelease,
    this.errorMessage,
    this.lastDownloadSha256,
    this.lastCheckedAt,
  });

  LibraryEntry copyWith({
    TrackedApp? app,
    AppCheckStatus? status,
    ReleaseInfo? latestRelease,
    String? errorMessage,
    String? lastDownloadSha256,
    DateTime? lastCheckedAt,
  }) => LibraryEntry(
    app: app ?? this.app,
    status: status ?? this.status,
    latestRelease: latestRelease ?? this.latestRelease,
    errorMessage: errorMessage ?? this.errorMessage,
    lastDownloadSha256: lastDownloadSha256 ?? this.lastDownloadSha256,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
  );
}
