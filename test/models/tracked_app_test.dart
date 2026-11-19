import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/tracked_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackedApp.initials', () {
    test('two-word name uses first letter of each word', () {
      final app = _app('MijnBudget Pro');
      expect(app.initials, 'MP');
    });

    test('single word uses its first two letters', () {
      final app = _app('MijnBudget');
      expect(app.initials, 'MI');
    });
  });

  group('TrackedApp JSON', () {
    test('round-trips through toJson/fromJson', () {
      final app = TrackedApp(
        id: '123',
        name: 'TaalLeer',
        sourceType: AppSourceType.github,
        sourceIdentifier: 'Hidde-Balestra/taalleer',
        isCurated: true,
        installedVersion: '1.8.0',
        packageName: 'nl.hiddebalestra.taalleer',
        lastInstalledAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        skippedVersion: '1.9.0',
        includePrereleases: true,
      );

      final restored = TrackedApp.fromJson(app.toJson());

      expect(restored.id, app.id);
      expect(restored.name, app.name);
      expect(restored.sourceType, app.sourceType);
      expect(restored.sourceIdentifier, app.sourceIdentifier);
      expect(restored.isCurated, app.isCurated);
      expect(restored.installedVersion, app.installedVersion);
      expect(restored.packageName, app.packageName);
      expect(restored.lastInstalledAt, app.lastInstalledAt);
      expect(restored.skippedVersion, app.skippedVersion);
      expect(restored.includePrereleases, app.includePrereleases);
    });

    test('fromJson defaults includePrereleases to false when absent', () {
      final app = TrackedApp.fromJson({
        'id': '123',
        'name': 'TaalLeer',
        'sourceType': 'github',
        'sourceIdentifier': 'Hidde-Balestra/taalleer',
      });

      expect(app.includePrereleases, isFalse);
    });

    test('fromJson defaults lastInstalledAt/skippedVersion to null when '
        'absent', () {
      final app = TrackedApp.fromJson({
        'id': '123',
        'name': 'TaalLeer',
        'sourceType': 'github',
        'sourceIdentifier': 'Hidde-Balestra/taalleer',
      });

      expect(app.lastInstalledAt, isNull);
      expect(app.skippedVersion, isNull);
    });

    test('fromJson defaults packageName to null when absent', () {
      final app = TrackedApp.fromJson({
        'id': '123',
        'name': 'TaalLeer',
        'sourceType': 'github',
        'sourceIdentifier': 'Hidde-Balestra/taalleer',
      });

      expect(app.packageName, isNull);
    });
  });

  group('TrackedApp.sourceUrl', () {
    test(
      'github builds a real https URL, unlike the schemeless sourceLabel',
      () {
        final app = TrackedApp(
          id: 'x',
          name: 'TaalLeer',
          sourceType: AppSourceType.github,
          sourceIdentifier: 'Hidde-Balestra/taalleer',
        );

        expect(app.sourceUrl, 'https://github.com/Hidde-Balestra/taalleer');
        expect(app.sourceLabel, 'github.com/Hidde-Balestra/taalleer');
      },
    );

    test('gitlab builds a real https URL', () {
      final app = TrackedApp(
        id: 'x',
        name: 'App',
        sourceType: AppSourceType.gitlab,
        sourceIdentifier: 'owner/repo',
      );

      expect(app.sourceUrl, 'https://gitlab.com/owner/repo');
    });

    test('codeberg builds a real https URL', () {
      final app = TrackedApp(
        id: 'x',
        name: 'App',
        sourceType: AppSourceType.codeberg,
        sourceIdentifier: 'owner/repo',
      );

      expect(app.sourceUrl, 'https://codeberg.org/owner/repo');
    });

    test('fdroid links to the package\'s f-droid.org page', () {
      final app = TrackedApp(
        id: 'x',
        name: 'App',
        sourceType: AppSourceType.fdroid,
        sourceIdentifier: 'org.example.app',
      );

      expect(app.sourceUrl, 'https://f-droid.org/packages/org.example.app/');
    });

    test('accrescent builds a real https URL', () {
      final app = TrackedApp(
        id: 'x',
        name: 'App',
        sourceType: AppSourceType.accrescent,
        sourceIdentifier: 'org.example.app',
      );

      expect(app.sourceUrl, 'https://accrescent.app/app/org.example.app');
    });

    test('direct uses the already-complete URL as-is', () {
      final app = _app('App');

      expect(app.sourceUrl, 'https://example.com/app.apk');
    });
  });

  group('TrackedApp.copyWith', () {
    test('sets packageName without touching other fields', () {
      final app = _app('TaalLeer');

      final updated = app.copyWith(packageName: 'nl.hiddebalestra.taalleer');

      expect(updated.packageName, 'nl.hiddebalestra.taalleer');
      expect(updated.name, app.name);
      expect(updated.installedVersion, app.installedVersion);
    });

    test('sets skippedVersion without touching other fields', () {
      final app = _app('TaalLeer');

      final updated = app.copyWith(skippedVersion: '2.0.0');

      expect(updated.skippedVersion, '2.0.0');
      expect(updated.name, app.name);
    });

    test('clearSkippedVersion nulls it out even though it was set', () {
      final app = _app('TaalLeer').copyWith(skippedVersion: '2.0.0');

      final updated = app.copyWith(clearSkippedVersion: true);

      expect(updated.skippedVersion, isNull);
    });
  });
}

TrackedApp _app(String name) => TrackedApp(
  id: 'x',
  name: name,
  sourceType: AppSourceType.direct,
  sourceIdentifier: 'https://example.com/app.apk',
);
