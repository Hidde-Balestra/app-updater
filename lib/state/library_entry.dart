import '../models/release_info.dart';
import '../models/tracked_app.dart';

enum AppCheckStatus { checking, upToDate, updateAvailable, error, noReleases }

/// A tracked app combined with its last-fetched release status. The status
/// itself is never persisted — it's re-derived from the network on every
/// check, only [TrackedApp.installedVersion] is saved to disk.
class LibraryEntry {
  final TrackedApp app;
  final AppCheckStatus status;
  final ReleaseInfo? latestRelease;
  final String? errorMessage;

  const LibraryEntry({
    required this.app,
    required this.status,
    this.latestRelease,
    this.errorMessage,
  });

  LibraryEntry copyWith({
    TrackedApp? app,
    AppCheckStatus? status,
    ReleaseInfo? latestRelease,
    String? errorMessage,
  }) => LibraryEntry(
    app: app ?? this.app,
    status: status ?? this.status,
    latestRelease: latestRelease ?? this.latestRelease,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
