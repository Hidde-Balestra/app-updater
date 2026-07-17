import '../models/app_source_type.dart';
import '../models/release_info.dart';
import 'fdroid_service.dart';
import 'github_service.dart';

/// Dispatches a source (type + identifier) to the right service. Direct
/// .apk URLs carry no version metadata by themselves, so they resolve to a
/// fixed ReleaseInfo with an empty version — the UI treats "not yet
/// installed" as the only update signal for that source type.
class ReleaseResolver {
  final GithubService _github;
  final FdroidService _fdroid;

  ReleaseResolver({GithubService? github, FdroidService? fdroid})
    : _github = github ?? GithubService(),
      _fdroid = fdroid ?? FdroidService();

  Future<ReleaseResult> resolve(AppSourceType type, String sourceIdentifier) {
    switch (type) {
      case AppSourceType.github:
        return _github.fetchLatestRelease(sourceIdentifier);
      case AppSourceType.fdroid:
        return _fdroid.fetchLatestRelease(sourceIdentifier);
      case AppSourceType.direct:
        return resolveDirect(sourceIdentifier);
    }
  }

  Future<ReleaseResult> resolveDirect(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || !trimmed.toLowerCase().endsWith('.apk')) {
      return const ReleaseError('invalid_source');
    }
    return ReleaseSuccess(
      ReleaseInfo(version: '', downloadUrl: trimmed, sourcePageUrl: trimmed),
    );
  }
}
