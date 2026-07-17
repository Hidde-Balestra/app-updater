import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/release_info.dart';

/// Resolves the latest release for an F-Droid package id via F-Droid's
/// public index API, and builds the direct repo download URL for the
/// matching APK.
class FdroidService {
  final http.Client _client;

  FdroidService({http.Client? client}) : _client = client ?? http.Client();

  Future<ReleaseResult> fetchLatestRelease(String packageId) async {
    final id = packageId.trim();
    if (id.isEmpty) {
      return const ReleaseError('invalid_source');
    }
    final uri = Uri.parse('https://f-droid.org/api/v1/packages/$id');
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 404) {
        return const ReleaseNotFound();
      }
      if (response.statusCode != 200) {
        return ReleaseError('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final packages = (json['packages'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (packages.isEmpty) {
        return const ReleaseNotFound();
      }
      // F-Droid returns packages newest-first.
      final latest = packages.first;
      final versionName = latest['versionName'] as String?;
      final apkName = latest['apkName'] as String?;
      if (versionName == null || apkName == null) {
        return const ReleaseNotFound();
      }

      return ReleaseSuccess(
        ReleaseInfo(
          version: versionName,
          changelog: null,
          downloadUrl: 'https://f-droid.org/repo/$apkName',
          sizeBytes: latest['size'] as int?,
          sourcePageUrl: 'https://f-droid.org/packages/$id/',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }
}
