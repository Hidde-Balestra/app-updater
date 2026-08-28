import 'package:app_updater/services/background_scheduler.dart';
import 'package:app_updater/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScheduleCall {
  final Duration interval;
  final bool wifiOnly;
  _ScheduleCall(this.interval, this.wifiOnly);
}

class _FakeBackgroundScheduler extends BackgroundScheduler {
  final List<_ScheduleCall> scheduleCalls = [];
  int cancelCalls = 0;

  @override
  Future<void> schedule(Duration interval, {bool wifiOnly = false}) async {
    scheduleCalls.add(_ScheduleCall(interval, wifiOnly));
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'load() schedules the background check when auto-check is on by default',
    () async {
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);

      await settings.load();

      expect(scheduler.scheduleCalls, hasLength(1));
      expect(
        scheduler.scheduleCalls.single.interval,
        const Duration(hours: 12),
      );
      expect(scheduler.scheduleCalls.single.wifiOnly, isTrue);
    },
  );

  test(
    'load() does not schedule when auto-check was persisted as off',
    () async {
      SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);

      await settings.load();

      expect(scheduler.scheduleCalls, isEmpty);
    },
  );

  test('setAutoCheckEnabled(false) cancels the background check', () async {
    final scheduler = _FakeBackgroundScheduler();
    final settings = SettingsController(scheduler: scheduler);
    await settings.load();

    await settings.setAutoCheckEnabled(false);

    expect(scheduler.cancelCalls, 1);
  });

  test(
    'setAutoCheckEnabled(true) (re)schedules the background check',
    () async {
      SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);
      await settings.load();
      expect(scheduler.scheduleCalls, isEmpty);

      await settings.setAutoCheckEnabled(true);

      expect(scheduler.scheduleCalls, hasLength(1));
    },
  );

  test(
    'setWifiOnly reschedules with the new constraint while auto-check is on',
    () async {
      final scheduler = _FakeBackgroundScheduler();
      final settings = SettingsController(scheduler: scheduler);
      await settings.load();
      scheduler.scheduleCalls.clear();

      await settings.setWifiOnly(false);

      expect(scheduler.scheduleCalls, hasLength(1));
      expect(scheduler.scheduleCalls.single.wifiOnly, isFalse);
    },
  );

  test('setWifiOnly does not schedule while auto-check is off', () async {
    SharedPreferences.setMockInitialValues({'settings.autoCheck': false});
    final scheduler = _FakeBackgroundScheduler();
    final settings = SettingsController(scheduler: scheduler);
    await settings.load();

    await settings.setWifiOnly(false);

    expect(scheduler.scheduleCalls, isEmpty);
  });
}
