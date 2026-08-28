import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/release_info.dart';

/// Resolves the latest release for an F-Droid package id via F-Droid's
/// public per-app API, and builds the repo download URL for the matching
/// APK.
///
/// As of the current API (confirmed against the live endpoint and
/// F-Droid's own "All our APIs" docs), `/api/v1/packages/{id}` only
/// returns `versionName`/`versionCode` per package — no `apkName`, `hash`,
/// or `size` anymore (those were dropped from this endpoint; the full
/// repo index has them, but at 50+ MB it's far too large to fetch for a
/// single-app check). The APK filename follows F-Droid's well-known,
/// stable naming convention instead: `<packageName>_<versionCode>.apk`
/// under `https://f-droid.org/repo/` — confirmed by hand to resolve to a
/// real download.
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
      final packageName = json['packageName'] as String? ?? id;
      final suggestedVersionCode = json['suggestedVersionCode'] as int?;
      final packages = (json['packages'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (packages.isEmpty) {
        return const ReleaseNotFound();
      }

      // The list can lead with newer pre-release/alpha builds, so prefer
      // whichever entry matches F-Droid's own suggested (stable) version
      // rather than always taking the first one.
      final suggested = packages.firstWhere(
        (p) => p['versionCode'] == suggestedVersionCode,
        orElse: () => packages.first,
      );
      final versionName = suggested['versionName'] as String?;
      final versionCode = suggested['versionCode'] as int?;
      if (versionName == null || versionCode == null) {
        return const ReleaseNotFound();
      }

      return ReleaseSuccess(
        ReleaseInfo(
          version: versionName,
          changelog: null,
          downloadUrl:
              'https://f-droid.org/repo/${packageName}_$versionCode.apk',
          sourcePageUrl: 'https://f-droid.org/packages/$id/',
        ),
      );
    } catch (e) {
      return ReleaseError(e.toString());
    }
  }
}
