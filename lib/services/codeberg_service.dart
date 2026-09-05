import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/release_info.dart';

/// Resolves the latest release + .apk asset for an "owner/repo" Codeberg
/// source using its public Gitea/Forgejo API (no auth required for public
/// repos). Same JSON shape as GitHub's Releases API, just a different host
/// and path prefix.
class CodebergService {
  final http.Client _client;

  CodebergService({http.Client? client}) : _client = client ?? http.Client();

  /// [token] is an optional Codeberg (Gitea/Forgejo) access token — when
  /// set, it's sent as an `Authorization: token <token>` header to raise
  /// the request from the unauthenticated rate limit.
  Future<ReleaseResult> fetchLatestRelease(
    String ownerRepo, {
    String? token,
  }) async {
    final repo = ownerRepo.trim();
    if (repo.isEmpty || !repo.contains('/')) {
      return const ReleaseError('invalid_source');
    }
    final uri = Uri.parse(
      'https://codeberg.org/api/v1/repos/$repo/releases/latest',
    );
    try {
      final response = await _client.get(
        uri,
        headers: {
          if (token != null && token.trim().isNotEmpty)
            'Authorization': 'token ${token.trim()}',
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
              'https://codeberg.org/$repo/releases',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }
}
