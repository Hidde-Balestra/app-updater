import 'dart:convert';

import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/gitlab_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves a .apk from a structured release asset link', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://gitlab.com/api/v4/projects/owner%2Frepo/releases/permalink/latest',
      );
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.1.0',
          'description': 'Changelog:\n- Fixed things',
          '_links': {'self': 'https://gitlab.com/owner/repo/-/releases/v2.1.0'},
          'assets': {
            'links': [
              {
                'name': 'app.apk',
                'direct_asset_url':
                    'https://gitlab.com/owner/repo/-/releases/v2.1.0/downloads/app.apk',
              },
            ],
          },
        }),
        200,
      );
    });

    final result = await GitlabService(
      client: client,
    ).fetchLatestRelease('owner/repo');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '2.1.0');
    expect(
      info.downloadUrl,
      'https://gitlab.com/owner/repo/-/releases/v2.1.0/downloads/app.apk',
    );
    expect(
      info.sourcePageUrl,
      'https://gitlab.com/owner/repo/-/releases/v2.1.0',
    );
    expect(info.changelog, 'Changelog:\n- Fixed things');
  });

  test('falls back to a markdown-embedded apk link in the description '
      '(Aurora Store style), rewriting relative /uploads/ paths to the API '
      'endpoint', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': '4.8.4',
          'description':
              'Changelog : v4.8.4\n'
              '- Bug fixes\n\n'
              '[AuroraStore-4.8.4.apk](/uploads/abc123/AuroraStore-4.8.4.apk)\n\n'
              '[AuroraStore-hw-4.8.4.apk](/uploads/def456/AuroraStore-hw-4.8.4.apk)',
          'assets': {'links': []},
        }),
        200,
      );
    });

    final result = await GitlabService(
      client: client,
    ).fetchLatestRelease('AuroraOSS/AuroraStore');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '4.8.4');
    expect(
      info.downloadUrl,
      'https://gitlab.com/api/v4/projects/AuroraOSS%2FAuroraStore/uploads/abc123/AuroraStore-4.8.4.apk',
    );
    // The download-link lines are stripped from the shown changelog.
    expect(info.changelog, isNot(contains('.apk')));
    expect(info.changelog, contains('Bug fixes'));
  });

  test('returns ReleaseNotFound when no .apk link exists anywhere', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.0.0',
          'description': 'No binaries here',
          'assets': {'links': []},
        }),
        200,
      );
    });

    final result = await GitlabService(
      client: client,
    ).fetchLatestRelease('owner/repo');

    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseNotFound on 404', () async {
    final client = MockClient((request) async => http.Response('', 404));
    final result = await GitlabService(
      client: client,
    ).fetchLatestRelease('owner/doesnotexist');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseError on unexpected status code', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final result = await GitlabService(
      client: client,
    ).fetchLatestRelease('owner/repo');
    expect(result, isA<ReleaseError>());
  });

  test('returns ReleaseError for a malformed source', () async {
    final result = await GitlabService().fetchLatestRelease('not-a-project');
    expect(result, isA<ReleaseError>());
  });

  test('URL-encodes nested group paths', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://gitlab.com/api/v4/projects/group%2Fsubgroup%2Fproject/releases/permalink/latest',
      );
      return http.Response('', 404);
    });

    await GitlabService(
      client: client,
    ).fetchLatestRelease('group/subgroup/project');
  });

  test('sends a PRIVATE-TOKEN header when a token is given', () async {
    String? tokenHeader;
    final client = MockClient((request) async {
      tokenHeader = request.headers['PRIVATE-TOKEN'];
      return http.Response('', 404);
    });

    await GitlabService(
      client: client,
    ).fetchLatestRelease('owner/repo', token: 'glpat-example');

    expect(tokenHeader, 'glpat-example');
  });

  test('omits the PRIVATE-TOKEN header when no token is given', () async {
    String? tokenHeader;
    final client = MockClient((request) async {
      tokenHeader = request.headers['PRIVATE-TOKEN'];
      return http.Response('', 404);
    });

    await GitlabService(client: client).fetchLatestRelease('owner/repo');

    expect(tokenHeader, isNull);
  });
}
