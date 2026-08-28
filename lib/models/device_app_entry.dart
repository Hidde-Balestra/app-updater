import 'installed_app.dart';

/// Where an installed app stands relative to the user's tracked-apps list,
/// for the combined "device apps" overview in Settings.
enum DeviceAppStatus {
  /// Already tracked (matched by package name) — nothing to do here.
  tracked,

  /// Explicitly dismissed by the user; hidden from add-app suggestions
  /// until un-ignored.
  ignored,

  /// Installed, not tracked, not ignored — a candidate the user could add.
  available,
}

class DeviceAppEntry {
  final InstalledApp app;
  final DeviceAppStatus status;

  const DeviceAppEntry({required this.app, required this.status});
}
