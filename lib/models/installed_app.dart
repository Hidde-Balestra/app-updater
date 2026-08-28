/// A minimal, plugin-agnostic view of an app installed on the device —
/// just enough to show it in the "scan device" list and prefill the add-app
/// form. Deliberately doesn't carry the `installed_apps` package's own
/// `AppInfo` type, consistent with how the rest of the app keeps
/// third-party service types out of its own models (see [ReleaseInfo]).
class InstalledApp {
  final String name;
  final String packageName;
  final String versionName;

  const InstalledApp({
    required this.name,
    required this.packageName,
    required this.versionName,
  });
}
