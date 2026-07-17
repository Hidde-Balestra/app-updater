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
      );

      final restored = TrackedApp.fromJson(app.toJson());

      expect(restored.id, app.id);
      expect(restored.name, app.name);
      expect(restored.sourceType, app.sourceType);
      expect(restored.sourceIdentifier, app.sourceIdentifier);
      expect(restored.isCurated, app.isCurated);
      expect(restored.installedVersion, app.installedVersion);
    });
  });
}

TrackedApp _app(String name) => TrackedApp(
  id: 'x',
  name: name,
  sourceType: AppSourceType.direct,
  sourceIdentifier: 'https://example.com/app.apk',
);
