import 'dart:convert';

import 'package:app_updater/models/release_info.dart';
import 'package:app_updater/services/fdroid_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves the newest package entry into a repo download URL', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://f-droid.org/api/v1/packages/org.fdroid.fdroid');
      return http.Response(
        jsonEncode({
          'packages': [
            {'versionName': '1.20', 'versionCode': 1020050, 'apkName': 'org.fdroid.fdroid_1020050.apk', 'size': 12345},
            {'versionName': '1.19', 'versionCode': 1019000, 'apkName': 'org.fdroid.fdroid_1019000.apk', 'size': 12000},
          ],
        }),
        200,
      );
    });

    final result = await FdroidService(client: client).fetchLatestRelease('org.fdroid.fdroid');

    expect(result, isA<ReleaseSuccess>());
    final info = (result as ReleaseSuccess).info;
    expect(info.version, '1.20');
    expect(info.downloadUrl, 'https://f-droid.org/repo/org.fdroid.fdroid_1020050.apk');
  });

  test('returns ReleaseNotFound when there are no packages', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({'packages': []}), 200));
    final result = await FdroidService(client: client).fetchLatestRelease('some.unknown.id');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseNotFound on 404', () async {
    final client = MockClient((request) async => http.Response('', 404));
    final result = await FdroidService(client: client).fetchLatestRelease('some.unknown.id');
    expect(result, isA<ReleaseNotFound>());
  });

  test('returns ReleaseError for empty input', () async {
    final result = await FdroidService().fetchLatestRelease('   ');
    expect(result, isA<ReleaseError>());
  });
}
