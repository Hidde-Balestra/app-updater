import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/fdroid_search_result.dart';

/// Full-text search across F-Droid's entire catalog, via the public
/// web-search API behind https://search.f-droid.org (documented in
/// F-Droid's "All our APIs" — distinct from the per-package
/// `/api/v1/packages/{id}` lookup in [FdroidService], which needs an exact,
/// already-known package id). Backs the "F-Droid" tab in the add-app flow,
/// so the user can browse the catalog by app name instead of only being
/// able to auto-match an app already installed on the device.
class FdroidSearchService {
  final http.Client _client;

  FdroidSearchService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<FdroidSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.https('search.f-droid.org', '/api/search_apps', {
      'q': trimmed,
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final apps = (json['apps'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return apps
        .map(_toResult)
        .whereType<FdroidSearchResult>()
        .toList(growable: false);
  }

  FdroidSearchResult? _toResult(Map<String, dynamic> app) {
    final packageId = _packageIdFrom(app['url'] as String?);
    if (packageId == null) return null;
    return FdroidSearchResult(
      name: app['name'] as String? ?? packageId,
      summary: app['summary'] as String? ?? '',
      packageId: packageId,
      iconUrl: app['icon'] as String?,
    );
  }

  /// Pulls the package id out of a result's "url", e.g.
  /// "https://f-droid.org/en/packages/org.example.app" -> "org.example.app".
  String? _packageIdFrom(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final index = uri.pathSegments.indexOf('packages');
    if (index == -1 || index + 1 >= uri.pathSegments.length) return null;
    final id = uri.pathSegments[index + 1];
    return id.isEmpty ? null : id;
  }
}
