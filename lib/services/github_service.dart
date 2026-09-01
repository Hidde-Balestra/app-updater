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
  Future<ReleaseResult> fetchLatestRelease(
    String ownerRepo, {
    String? token,
  }) async {
    final repo = ownerRepo.trim();
    if (repo.isEmpty || !repo.contains('/')) {
      return const ReleaseError('invalid_source');
    }
    final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
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
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = (json['assets'] as List? ?? const [])
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

      final tagName = json['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      return ReleaseSuccess(
        ReleaseInfo(
          version: version.isEmpty ? tagName : version,
          changelog: json['body'] as String?,
          downloadUrl: apkAsset['browser_download_url'] as String,
          sizeBytes: apkAsset['size'] as int?,
          sourcePageUrl:
              json['html_url'] as String? ??
              'https://github.com/$repo/releases',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }
}
