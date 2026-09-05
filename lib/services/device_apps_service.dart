import 'dart:typed_data';

import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app.dart';

/// Reads an app's installed version straight from the device's package
/// manager (via the `installed_apps` plugin), keyed by Android package
/// name. Used to sync a tracked app's installed version with what's
/// actually on the device, so update checks stay accurate even for apps
/// that were installed outside of a download-and-install performed through
/// this app.
class DeviceAppsService {
  /// Returns the installed `versionName` for [packageName], or null if the
  /// package name is blank or the app isn't installed on this device.
  Future<String?> installedVersion(String packageName) async {
    final trimmed = packageName.trim();
    if (trimmed.isEmpty) return null;
    final info = await InstalledApps.getAppInfo(trimmed);
    return info?.versionName;
  }

  /// Returns the installed app's real launcher icon as PNG bytes, or null
  /// if the package name is blank or the app isn't installed. Used to show
  /// a real icon on the detail screen instead of the generic colored-
  /// initials avatar, for an app that's actually on the device.
  Future<Uint8List?> installedIcon(String packageName) async {
    final trimmed = packageName.trim();
    if (trimmed.isEmpty) return null;
    final info = await InstalledApps.getAppInfo(trimmed);
    return info?.icon;
  }

  /// Package names of every launchable, non-system app currently installed.
  /// Used to diff a before/after snapshot and spot the package that just
  /// got installed, since neither Android nor open_filex tells this app
  /// which package the user actually confirmed installing.
  Future<Set<String>> installedPackageNames() async {
    final apps = await installedApps();
    return apps.map((app) => app.packageName).toSet();
  }

  /// Every launchable, non-system app currently installed on the device,
  /// for the "scan device" tab in the add-app flow.
  Future<List<InstalledApp>> installedApps() async {
    final apps = await InstalledApps.getInstalledApps();
    return apps
        .map(
          (app) => InstalledApp(
            name: app.name,
            packageName: app.packageName,
            versionName: app.versionName,
          ),
        )
        .toList();
  }
}
