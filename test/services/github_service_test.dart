import 'dart:convert';

import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/github_service.dart';
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
          'https://api.github.com/repos/Hidde-Balestra/taalleer/releases/latest',
        );
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.8.0',
            'html_url':
                'https://github.com/Hidde-Balestra/taalleer/releases/tag/v1.8.0',
            'body': 'Line one\nLine two',
            'assets': [
              {
                'name': 'taalleer-v1.8.0-universal.apk',
                'browser_download_url':
                    'https://github.com/Hidde-Balestra/taalleer/releases/download/v1.8.0/taalleer-v1.8.0-universal.apk',
                'size': 47955116,
              },
            ],
          }),
          200,
        );
      });

      final result = await GithubService(
        client: client,
      ).fetchLatestRelease('Hidde-Balestra/taalleer');

      expect(result, isA<ReleaseSuccess>());
      final info = (result as ReleaseSuccess).info;
      expect(info.version, '1.8.0');
      expect(info.sizeBytes, 47955116);
      expect(info.downloadUrl, endsWith('taalleer-v1.8.0-universal.apk'));
    },
  );

  test('ignores non-apk assets and picks the first apk match', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.2.2',
          'html_url':
              'https://github.com/privacy-creator/musicplayer-flutter/releases/tag/v2.2.2',
          'body': null,
          'assets': [
            {
              'name': 'MusicPlayer-v2.2.2-windows.zip',
              'browser_download_url': 'https://x/windows.zip',
              'size': 1,
            },
            {
              'name': 'MusicPlayer-v2.2.2-android.apk',
              'browser_download_url': 'https://x/android.apk',
              'size': 2,
            },
          ],
        }),
        200,
      );
    });

    final result = await GithubService(
      client: client,
    ).fetchLatestRelease('privacy-creator/musicplayer-flutter');

    expect(result, isA<ReleaseSuccess>());
    expect(
      (result as ReleaseSuccess).info.downloadUrl,
      'https://x/android.apk',
    );
  });

  test('returns ReleaseNotFound on 404', () async {
    final client = MockClient((request) async => http.Response('', 404));
    final result = await GithubService(
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
    final result = await GithubService(
      client: client,
    ).fetchLatestRelease('owner/repo');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseError on unexpected status code', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final result = await GithubService(
      client: client,
    ).fetchLatestRelease('owner/repo');
    expect(result, isA<ReleaseError>());
  });

  test('returns ReleaseError for a malformed source', () async {
    final result = await GithubService().fetchLatestRelease(
      'not-a-valid-source',
    );
    expect(result, isA<ReleaseError>());
  });
}
