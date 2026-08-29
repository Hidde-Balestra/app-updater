import 'package:app_updater/models/source_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGithubSource', () {
    test('accepts bare owner/repo', () {
      expect(
        parseGithubSource('Hidde-Balestra/taalleer'),
        'Hidde-Balestra/taalleer',
      );
    });

    test('accepts a github.com repo URL', () {
      expect(
        parseGithubSource('https://github.com/Hidde-Balestra/Task_Planner'),
        'Hidde-Balestra/Task_Planner',
      );
    });

    test('accepts a github.com releases URL', () {
      expect(
        parseGithubSource(
          'https://github.com/Hidde-Balestra/taalleer/releases',
        ),
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

  group('parseGitlabSource', () {
    test('accepts bare namespace/project', () {
      expect(
        parseGitlabSource('AuroraOSS/AuroraStore'),
        'AuroraOSS/AuroraStore',
      );
    });

    test('accepts nested groups', () {
      expect(
        parseGitlabSource('group/subgroup/project'),
        'group/subgroup/project',
      );
    });

    test('accepts a gitlab.com project URL', () {
      expect(
        parseGitlabSource('https://gitlab.com/AuroraOSS/AuroraStore'),
        'AuroraOSS/AuroraStore',
      );
    });

    test('accepts a gitlab.com releases URL, dropping the -/releases tail', () {
      expect(
        parseGitlabSource(
          'https://gitlab.com/AuroraOSS/AuroraStore/-/releases',
        ),
        'AuroraOSS/AuroraStore',
      );
    });

    test('rejects a non-gitlab host', () {
      expect(parseGitlabSource('https://github.com/owner/repo'), isNull);
    });

    test('rejects empty input', () {
      expect(parseGitlabSource('   '), isNull);
    });

    test('rejects a bare value with no slash', () {
      expect(parseGitlabSource('notaproject'), isNull);
    });
  });

  group('parseCodebergSource', () {
    test('accepts bare owner/repo', () {
      expect(parseCodebergSource('gsantner/markor'), 'gsantner/markor');
    });

    test('accepts a codeberg.org repo URL', () {
      expect(
        parseCodebergSource('https://codeberg.org/gsantner/markor'),
        'gsantner/markor',
      );
    });

    test('accepts a codeberg.org releases URL', () {
      expect(
        parseCodebergSource('https://codeberg.org/gsantner/markor/releases'),
        'gsantner/markor',
      );
    });

    test('rejects a non-codeberg host', () {
      expect(parseCodebergSource('https://github.com/owner/repo'), isNull);
    });

    test('rejects empty input', () {
      expect(parseCodebergSource('   '), isNull);
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

  group('parseAccrescentSource', () {
    test('accepts a bare application id', () {
      expect(parseAccrescentSource('app.organicmaps'), 'app.organicmaps');
    });

    test('accepts an accrescent.app/app/<id> deep link', () {
      expect(
        parseAccrescentSource('https://accrescent.app/app/app.organicmaps'),
        'app.organicmaps',
      );
    });

    test('rejects a URL without an app segment', () {
      expect(parseAccrescentSource('https://accrescent.app/'), isNull);
    });

    test('rejects empty input', () {
      expect(parseAccrescentSource('   '), isNull);
    });
  });

  group('defaultNameFor', () {
    test('github uses the repo name', () {
      expect(
        defaultNameFor(
          identifierKind: 'github',
          identifier: 'Hidde-Balestra/taalleer',
        ),
        'taalleer',
      );
    });

    test('gitlab uses the project name', () {
      expect(
        defaultNameFor(
          identifierKind: 'gitlab',
          identifier: 'AuroraOSS/AuroraStore',
        ),
        'AuroraStore',
      );
    });

    test('codeberg uses the repo name', () {
      expect(
        defaultNameFor(identifierKind: 'codeberg', identifier: 'owner/repo'),
        'repo',
      );
    });

    test('direct strips the .apk extension', () {
      expect(
        defaultNameFor(
          identifierKind: 'direct',
          identifier: 'https://f-droid.org/F-Droid.apk',
        ),
        'F-Droid',
      );
    });

    test('accrescent uses the application id as-is', () {
      expect(
        defaultNameFor(
          identifierKind: 'accrescent',
          identifier: 'app.organicmaps',
        ),
        'app.organicmaps',
      );
    });
  });
}
