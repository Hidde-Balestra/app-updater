import 'package:app_updater/models/source_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGithubSource', () {
    test('accepts bare owner/repo', () {
      expect(parseGithubSource('Hidde-Balestra/taalleer'), 'Hidde-Balestra/taalleer');
    });

    test('accepts a github.com repo URL', () {
      expect(
        parseGithubSource('https://github.com/Hidde-Balestra/Task_Planner'),
        'Hidde-Balestra/Task_Planner',
      );
    });

    test('accepts a github.com releases URL', () {
      expect(
        parseGithubSource('https://github.com/Hidde-Balestra/taalleer/releases'),
        'Hidde-Balestra/taalleer',
      );
    });

    test('rejects a non-github host', () {
      expect(parseGithubSource('https://gitlab.com/owner/repo'), isNull);
    });

    test('rejects empty input', () {
      expect(parseGithubSource('   '), isNull);
    });
  });

  group('parseFdroidSource', () {
    test('accepts a bare package id', () {
      expect(parseFdroidSource('org.fdroid.fdroid'), 'org.fdroid.fdroid');
    });

    test('accepts a packages URL', () {
      expect(
        parseFdroidSource('https://f-droid.org/en/packages/org.fdroid.fdroid/'),
        'org.fdroid.fdroid',
      );
    });

    test('rejects a URL without a package segment', () {
      expect(parseFdroidSource('https://f-droid.org/en/'), isNull);
    });
  });

  group('defaultNameFor', () {
    test('github uses the repo name', () {
      expect(
        defaultNameFor(identifierKind: 'github', identifier: 'Hidde-Balestra/taalleer'),
        'taalleer',
      );
    });

    test('direct strips the .apk extension', () {
      expect(
        defaultNameFor(identifierKind: 'direct', identifier: 'https://f-droid.org/F-Droid.apk'),
        'F-Droid',
      );
    });
  });
}
