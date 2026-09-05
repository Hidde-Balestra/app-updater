import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/release_info.dart';

/// Regex for a markdown link ending in `.apk`, e.g.
/// `[AuroraStore-4.8.4.apk](/uploads/<hash>/AuroraStore-4.8.4.apk)`. Some
/// GitLab projects (Aurora Store among them) attach APKs by pasting an
/// upload link into the release description instead of using GitLab's
/// structured release-asset-links feature.
final _apkMarkdownLink = RegExp(r'\[[^\]]*\]\(([^)]+\.apk)\)');

/// Resolves the latest release + .apk asset for a GitLab "namespace/project"
/// source (nested groups allowed) using GitLab's public Releases API — no
/// auth required for public projects.
class GitlabService {
  final http.Client _client;

  GitlabService({http.Client? client}) : _client = client ?? http.Client();

  /// [token] is an optional GitLab personal/project access token — when
  /// set, it's sent as `PRIVATE-TOKEN` to raise the request from GitLab's
  /// unauthenticated rate limit.
  Future<ReleaseResult> fetchLatestRelease(
    String projectPath, {
    String? token,
  }) async {
    final path = projectPath.trim();
    if (path.isEmpty || !path.contains('/')) {
      return const ReleaseError('invalid_source');
    }
    final encodedPath = Uri.encodeComponent(path);
    final uri = Uri.parse(
      'https://gitlab.com/api/v4/projects/$encodedPath/releases/permalink/latest',
    );
    try {
      final response = await _client.get(
        uri,
        headers: {
          if (token != null && token.trim().isNotEmpty)
            'PRIVATE-TOKEN': token.trim(),
        },
      );
      if (response.statusCode == 404) {
        return const ReleaseNotFound();
      }
      if (response.statusCode != 200) {
        return ReleaseError('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final apkUrl = _findApkAsset(json, encodedPath);
      if (apkUrl == null) {
        return const ReleaseNotFound();
      }

      final tagName = json['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final links = json['_links'] as Map<String, dynamic>?;
      final webUrl = links?['self'] as String?;

      return ReleaseSuccess(
        ReleaseInfo(
          version: version.isEmpty ? tagName : version,
          changelog: _changelogWithoutAssetLinks(
            json['description'] as String?,
          ),
          downloadUrl: apkUrl,
          sourcePageUrl: webUrl ?? 'https://gitlab.com/$path/-/releases',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }

  /// Prefers a `.apk` among the release's structured asset links; falls
  /// back to the first `.apk` markdown link in the description otherwise.
  /// Relative `/uploads/...` links are rewritten to the API uploads
  /// endpoint — the web UI path for the same file blocks non-browser
  /// clients, but the API path serves it anonymously.
  String? _findApkAsset(Map<String, dynamic> json, String encodedPath) {
    final assets = json['assets'] as Map<String, dynamic>?;
    final links =
        (assets?['links'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final link in links) {
      final url = link['direct_asset_url'] as String? ?? link['url'] as String?;
      if (url != null && url.toLowerCase().endsWith('.apk')) return url;
    }

    final description = json['description'] as String? ?? '';
    final match = _apkMarkdownLink.firstMatch(description);
    final href = match?.group(1);
    if (href == null) return null;
    if (href.startsWith('/uploads/')) {
      return 'https://gitlab.com/api/v4/projects/$encodedPath$href';
    }
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    return null;
  }

  String? _changelogWithoutAssetLinks(String? description) {
    if (description == null) return null;
    return description
        .split('\n')
        .where((line) => !_apkMarkdownLink.hasMatch(line))
        .join('\n');
  }
}
