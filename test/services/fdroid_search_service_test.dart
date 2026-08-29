import 'dart:convert';

import 'package:app_updater/services/fdroid_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses name, summary, icon and package id from a real-shaped '
      'response', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'search.f-droid.org');
      expect(request.url.path, '/api/search_apps');
      expect(request.url.queryParameters['q'], 'signal');
      return http.Response(
        jsonEncode({
          'apps': [
            {
              'name': 'Molly',
              'summary': 'Signal fork with extra security features',
              'icon': 'https://example.com/molly.png',
              'url': 'https://f-droid.org/en/packages/im.molly.app',
            },
          ],
        }),
        200,
      );
    });

    final results = await FdroidSearchService(client: client).search('signal');

    expect(results, hasLength(1));
    expect(results.single.name, 'Molly');
    expect(results.single.summary, 'Signal fork with extra security features');
    expect(results.single.packageId, 'im.molly.app');
    expect(results.single.iconUrl, 'https://example.com/molly.png');
  });

  test('skips entries whose url has no parseable package id', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'apps': [
            {'name': 'Broken', 'summary': '', 'url': 'https://f-droid.org/'},
            {
              'name': 'Fine',
              'summary': '',
              'url': 'https://f-droid.org/en/packages/org.example.fine',
            },
          ],
        }),
        200,
      ),
    );

    final results = await FdroidSearchService(client: client).search('x');

    expect(results, hasLength(1));
    expect(results.single.packageId, 'org.example.fine');
  });

  test('returns an empty list for a blank query without any request', () async {
    final client = MockClient((request) async {
      fail('should not perform a request for a blank query');
    });

    final results = await FdroidSearchService(client: client).search('   ');

    expect(results, isEmpty);
  });

  test('throws on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('', 500));

    expect(
      () => FdroidSearchService(client: client).search('signal'),
      throwsException,
    );
  });
}
