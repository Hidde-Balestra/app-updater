class ReleaseInfo {
  final String version;
  final String? changelog;
  final String downloadUrl;
  final int? sizeBytes;
  final String sourcePageUrl;

  const ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.sourcePageUrl,
    this.changelog,
    this.sizeBytes,
  });
}

/// Result of resolving the latest release for a source. Kept as a sealed
/// class instead of throwing, so the UI can render "no releases" and
/// network-error states without try/catch at the call site.
sealed class ReleaseResult {
  const ReleaseResult();
}

class ReleaseSuccess extends ReleaseResult {
  final ReleaseInfo info;
  const ReleaseSuccess(this.info);
}

class ReleaseNotFound extends ReleaseResult {
  const ReleaseNotFound();
}

class ReleaseError extends ReleaseResult {
  final String message;
  const ReleaseError(this.message);
}
