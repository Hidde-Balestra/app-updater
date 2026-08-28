import 'package:app_updater/services/background_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clampToWorkManagerMinimum', () {
    test('leaves intervals at or above 15 minutes untouched', () {
      expect(
        clampToWorkManagerMinimum(const Duration(hours: 12)),
        const Duration(hours: 12),
      );
      expect(
        clampToWorkManagerMinimum(const Duration(minutes: 15)),
        const Duration(minutes: 15),
      );
    });

    test('rounds intervals below 15 minutes up to 15 minutes', () {
      expect(
        clampToWorkManagerMinimum(const Duration(minutes: 5)),
        const Duration(minutes: 15),
      );
      expect(
        clampToWorkManagerMinimum(Duration.zero),
        const Duration(minutes: 15),
      );
    });
  });
}
