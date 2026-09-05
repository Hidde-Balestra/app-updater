import 'dart:convert';

import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/codeberg_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'resolves the apk asset from a real-shaped releases/latest response',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://codeberg.org/api/v1/repos/gsantner/markor/releases/latest',
        );
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.14.2',
            'html_url':
                'https://codeberg.org/gsantner/markor/releases/tag/v2.14.2',
            'body': 'Release notes',
            'assets': [
              {
                'name': 'markor-2.14.2.apk',
                'browser_download_url':
                    'https://codeberg.org/gsantner/markor/releases/download/v2.14.2/markor-2.14.2.apk',
                'size': 12345678,
              },
            ],
          }),
          200,
        );
      });

      final result = await CodebergService(
        client: client,
      ).fetchLatestRelease('gsantner/markor');

      expect(result, isA<ReleaseSuccess>());
      final info = (result as ReleaseSuccess).info;
      expect(info.version, '2.14.2');
      expect(info.sizeBytes, 12345678);
      expect(info.downloadUrl, endsWith('markor-2.14.2.apk'));
    },
  );

  test('ignores non-apk assets and picks the first apk match', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.0.0',
          'body': null,
          'assets': [
            {
              'name': 'source.tar.gz',
              'browser_download_url': 'https://x/source.tar.gz',
              'size': 1,
            },
            {
              'name': 'app.apk',
              'browser_download_url': 'https://x/app.apk',
              'size': 2,
            },
          ],
        }),
        200,
      );
    });

    final result = await CodebergService(
      client: client,
    ).fetchLatestRelease('owner/repo');

    expect(result, isA<ReleaseSuccess>());
    expect((result as ReleaseSuccess).info.downloadUrl, 'https://x/app.apk');
  });

  test('returns ReleaseNotFound on 404', () async {
    final client = MockClient((request) async => http.Response('', 404));
    final result = await CodebergService(
      client: client,
    ).fetchLatestRelease('someone/doesnotexist');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseNotFound when no release has an apk asset', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'tag_name': 'v1.0.0', 'assets': []}),
        200,
      );
    });
    final result = await CodebergService(
      client: client,
    ).fetchLatestRelease('owner/repo');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseError on unexpected status code', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final result = await CodebergService(
      client: client,
    ).fetchLatestRelease('owner/repo');
    expect(result, isA<ReleaseError>());
  });

  test('returns ReleaseError for a malformed source', () async {
    final result = await CodebergService().fetchLatestRelease(
      'not-a-valid-source',
    );
    expect(result, isA<ReleaseError>());
  });

  test('sends an Authorization header when a token is given', () async {
    String? authHeader;
    final client = MockClient((request) async {
      authHeader = request.headers['Authorization'];
      return http.Response('', 404);
    });

    await CodebergService(
      client: client,
    ).fetchLatestRelease('owner/repo', token: 'example-token');

    expect(authHeader, 'token example-token');
  });

  test('omits the Authorization header when no token is given', () async {
    String? authHeader;
    final client = MockClient((request) async {
      authHeader = request.headers['Authorization'];
      return http.Response('', 404);
    });

    await CodebergService(client: client).fetchLatestRelease('owner/repo');

    expect(authHeader, isNull);
  });
}
