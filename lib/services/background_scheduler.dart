import 'package:workmanager/workmanager.dart';

import 'background_update_checker.dart';

/// Unique name (and task name) for the periodic update-check job. Also
/// doubles as the SharedPreferences-free identifier WorkManager uses to
/// replace/cancel the job, so it must stay stable across app versions.
const backgroundUpdateCheckTask = 'nl.hiddebalestra.app_updater.checkUpdates';

const _workManagerMinimum = Duration(minutes: 15);

/// Android's WorkManager silently rounds any periodic frequency below 15
/// minutes up to 15 minutes. Clamping here too means the interval shown in
/// Settings never lies about what's actually scheduled.
Duration clampToWorkManagerMinimum(Duration interval) =>
    interval < _workManagerMinimum ? _workManagerMinimum : interval;

/// Thin wrapper around the `workmanager` plugin so [SettingsController] can
/// depend on something fakeable in tests, rather than the plugin's
/// MethodChannel-backed singleton directly.
///
/// Android enforces a 15-minute minimum for periodic work, and silently
/// clamps anything shorter — [schedule] does the same so the interval shown
/// in Settings doesn't lie about what actually runs.
class BackgroundScheduler {
  Future<void> initialize() {
    return Workmanager().initialize(callbackDispatcher);
  }

  Future<void> schedule(Duration interval, {bool wifiOnly = false}) {
    return Workmanager().registerPeriodicTask(
      backgroundUpdateCheckTask,
      backgroundUpdateCheckTask,
      frequency: clampToWorkManagerMinimum(interval),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  Future<void> cancel() {
    return Workmanager().cancelByUniqueName(backgroundUpdateCheckTask);
  }
}

/// Entry point WorkManager calls in a background isolate. Must stay a
/// top-level function annotated with `vm:entry-point` so the AOT compiler
/// doesn't tree-shake it away — see the workmanager package docs.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundUpdateCheckTask) {
      await BackgroundUpdateChecker().run();
    }
    return true;
  });
}
