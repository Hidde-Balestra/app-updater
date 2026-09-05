import '../models/app_source_type.dart';
import '../models/release_info.dart';
import 'accrescent/accrescent_service.dart';
import 'codeberg_service.dart';
import 'fdroid_service.dart';
import 'github_service.dart';
import 'gitlab_service.dart';

/// Dispatches a source (type + identifier) to the right service. Direct
/// .apk URLs carry no version metadata by themselves, so they resolve to a
/// fixed ReleaseInfo with an empty version — the UI treats "not yet
/// installed" as the only update signal for that source type.
class ReleaseResolver {
  final GithubService _github;
  final GitlabService _gitlab;
  final CodebergService _codeberg;
  final FdroidService _fdroid;
  final AccrescentService _accrescent;

  ReleaseResolver({
    GithubService? github,
    GitlabService? gitlab,
    CodebergService? codeberg,
    FdroidService? fdroid,
    AccrescentService? accrescent,
  }) : _github = github ?? GithubService(),
       _gitlab = gitlab ?? GitlabService(),
       _codeberg = codeberg ?? CodebergService(),
       _fdroid = fdroid ?? FdroidService(),
       _accrescent = accrescent ?? AccrescentService();

  Future<ReleaseResult> resolve(
    AppSourceType type,
    String sourceIdentifier, {
    String? githubToken,
    String? gitlabToken,
    String? codebergToken,
  }) {
    switch (type) {
      case AppSourceType.github:
        return _github.fetchLatestRelease(sourceIdentifier, token: githubToken);
      case AppSourceType.gitlab:
        return _gitlab.fetchLatestRelease(sourceIdentifier, token: gitlabToken);
      case AppSourceType.codeberg:
        return _codeberg.fetchLatestRelease(
          sourceIdentifier,
          token: codebergToken,
        );
      case AppSourceType.fdroid:
        return _fdroid.fetchLatestRelease(sourceIdentifier);
      case AppSourceType.direct:
        return resolveDirect(sourceIdentifier);
      case AppSourceType.accrescent:
        return _accrescent.fetchLatestRelease(sourceIdentifier);
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
