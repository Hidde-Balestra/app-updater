import 'dart:convert';

import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves the suggested (stable) version into a repo download URL, '
      'not the newest list entry', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://f-droid.org/api/v1/packages/org.fdroid.fdroid',
      );
      // Real F-Droid API shape: no apkName/hash/size, and the list can
      // lead with a pre-release build newer than the suggested version.
      return http.Response(
        jsonEncode({
          'packageName': 'org.fdroid.fdroid',
          'suggestedVersionCode': 1023052,
          'packages': [
            {'versionName': '2.0-rc1', 'versionCode': 2000041},
            {'versionName': '1.23.2', 'versionCode': 1023052},
            {'versionName': '1.23.1', 'versionCode': 1023051},
          ],
        }),
        200,
      );
    });

    final result = await FdroidService(
      client: client,
    ).fetchLatestRelease('org.fdroid.fdroid');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '1.23.2');
    expect(
      info.downloadUrl,
      'https://f-droid.org/repo/org.fdroid.fdroid_1023052.apk',
    );
    expect(
      info.sourcePageUrl,
      'https://f-droid.org/packages/org.fdroid.fdroid/',
    );
  });

  test('falls back to the first package entry when nothing matches the '
      'suggested version code', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'packageName': 'org.example.app',
          'suggestedVersionCode': 999,
          'packages': [
            {'versionName': '2.0', 'versionCode': 200},
            {'versionName': '1.0', 'versionCode': 100},
          ],
        }),
        200,
      );
    });

    final result = await FdroidService(
      client: client,
    ).fetchLatestRelease('org.example.app');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '2.0');
    expect(
      info.downloadUrl,
      'https://f-droid.org/repo/org.example.app_200.apk',
    );
  });

  test('returns ReleaseNotFound when there are no packages', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'packageName': 'some.unknown.id', 'packages': []}),
        200,
      ),
    );
    final result = await FdroidService(
      client: client,
    ).fetchLatestRelease('some.unknown.id');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseNotFound on 404', () async {
    final client = MockClient((request) async => http.Response('', 404));
    final result = await FdroidService(
      client: client,
    ).fetchLatestRelease('some.unknown.id');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseError for empty input', () async {
    final result = await FdroidService().fetchLatestRelease('   ');
    expect(result, isA<ReleaseError>());
  });
}
