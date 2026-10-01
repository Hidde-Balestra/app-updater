import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/release_info.dart';

/// Resolves the latest release + .apk asset for a "owner/repo" GitHub
/// source using the public Releases API (no auth required for public repos,
/// but subject to GitHub's anonymous rate limit).
class GithubService {
  final http.Client _client;

  GithubService({http.Client? client}) : _client = client ?? http.Client();

  /// [token] is an optional GitHub personal access token — when set, it's
  /// sent as a Bearer token to raise the request from GitHub's unauthenticated
  /// rate limit (60/hour) to the authenticated one.
  ///
  /// [includePrereleases] switches from GitHub's `/releases/latest` endpoint
  /// (which always skips releases marked pre-release or draft) to the full
  /// `/releases` list, taking its first entry — for projects that only ever
  /// ship alpha/beta/rc builds and so would otherwise never have a "latest"
  /// release at all.
  Future<ReleaseResult> fetchLatestRelease(
    String ownerRepo, {
    String? token,
    bool includePrereleases = false,
  }) async {
    final repo = ownerRepo.trim();
    if (repo.isEmpty || !repo.contains('/')) {
      return const ReleaseError('invalid_source');
    }
    final path = includePrereleases ? 'releases' : 'releases/latest';
    final uri = Uri.parse('https://api.github.com/repos/$repo/$path');
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          if (token != null && token.trim().isNotEmpty)
            'Authorization': 'Bearer ${token.trim()}',
        },
      );
      if (response.statusCode == 404) {
        return const ReleaseNotFound();
      }
      if (response.statusCode != 200) {
        return ReleaseError('HTTP ${response.statusCode}');
      }

      final Map<String, dynamic>? release;
      if (includePrereleases) {
        final list = (jsonDecode(response.body) as List)
            .cast<Map<String, dynamic>>()
            .where((r) => r['draft'] != true);
        release = list.isEmpty ? null : list.first;
      } else {
        release = jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (release == null) {
        return const ReleaseNotFound();
      }

      final assets = (release['assets'] as List? ?? const [])
          .cast<Map<String, dynamic>>();

      Map<String, dynamic>? apkAsset;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkAsset = asset;
          break;
        }
      }
      if (apkAsset == null) {
        return const ReleaseNotFound();
      }

      final tagName = release['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      return ReleaseSuccess(
        ReleaseInfo(
          version: version.isEmpty ? tagName : version,
          changelog: release['body'] as String?,
          downloadUrl: apkAsset['browser_download_url'] as String,
          sizeBytes: apkAsset['size'] as int?,
          sourcePageUrl:
              release['html_url'] as String? ??
              'https://github.com/$repo/releases',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }
}
