import 'package:app_updater/services/background_scheduler.dart';

/// No-op [BackgroundScheduler] for widget tests that just need
/// [SettingsController] to not touch the real WorkManager platform channel
/// (which isn't mocked outside of dedicated scheduler tests). Tests that
/// actually assert on scheduling behaviour use their own recording fake —
/// see test/state/settings_controller_test.dart.
class FakeBackgroundScheduler extends BackgroundScheduler {
  @override
  Future<void> schedule(Duration interval, {bool wifiOnly = false}) async {}

  @override
  Future<void> cancel() async {}
}
