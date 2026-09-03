/// SharedPreferences keys shared between [AppLibrary]/[SettingsController]
/// and [BackgroundUpdateChecker]. The checker runs in a headless background
/// isolate and reads prefs directly rather than through those classes, so
/// the key strings must stay in exactly one place to avoid the two sides
/// silently drifting apart.
class StorageKeys {
  StorageKeys._();

  static const trackedApps = 'library.trackedApps';
  static const notificationsEnabled = 'settings.notifications';
  static const ignoredPackageNames = 'library.ignoredPackageNames';
  static const updateHistory = 'library.updateHistory';

  /// Secure-storage key (not SharedPreferences) for the optional GitHub
  /// personal access token — kept here anyway so the key name stays in one
  /// place between [SettingsController] and [BackgroundUpdateChecker].
  static const githubToken = 'settings.githubToken';
}
