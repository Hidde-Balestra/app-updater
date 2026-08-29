import 'app_source_type.dart';

/// Whether [latestVersion] should be offered as an update over
/// [installedVersion]. Deliberately a plain inequality check rather than
/// semver parsing: tracked apps don't all follow semver (tags like
/// "V.0.8.0" have been seen in the wild), so a strict parser would be more
/// likely to misfire than a simple "is it different" check.
///
/// The one normalization applied is stripping a leading "v"/"V" — that
/// prefix is purely decorative in every version scheme seen in the wild
/// (never meaningful version data), but the two sides of this comparison
/// often disagree on whether to include it: Android's own `versionName`
/// (what a device scan reports as installed) sometimes keeps it, while
/// GitHub tag names get it stripped by [GithubService] before being stored
/// as a release's version. Without normalizing, an app can be flagged as
/// having an update forever even when installed and latest are the exact
/// same release (seen in practice: "v8.19.2-4" vs "8.19.2-4").
bool isUpdateAvailable({
  required String? installedVersion,
  required String? latestVersion,
}) {
  if (latestVersion == null) return false;
  if (installedVersion == null) return true;
  return _stripVPrefix(installedVersion.trim()) !=
      _stripVPrefix(latestVersion.trim());
}

String _stripVPrefix(String version) {
  if (version.isEmpty) return version;
  final first = version[0];
  if ((first == 'v' || first == 'V') &&
      version.length > 1 &&
      RegExp(r'^[0-9]').hasMatch(version[1])) {
    return version.substring(1);
  }
  return version;
}

/// Whether a tracked app with [sourceType] should be considered to have an
/// update available, given its recorded [installedVersion] and the
/// [latestVersion] resolved from its source. Shared between [AppLibrary]'s
/// live status and the headless background checker so the two never
/// disagree on what counts as "has an update".
///
/// Direct `.apk` sources carry no version metadata of their own (see
/// [ReleaseResolver.resolveDirect]), so "not yet installed" is the only
/// signal available for them.
bool appHasUpdate({
  required AppSourceType sourceType,
  required String? installedVersion,
  required String? latestVersion,
}) {
  if (sourceType == AppSourceType.direct) {
    return installedVersion == null;
  }
  return isUpdateAvailable(
    installedVersion: installedVersion,
    latestVersion: latestVersion,
  );
}

/// Whether [latestVersion] is exactly the version a user previously chose
/// to skip. Shared between [AppLibrary]'s live status and the headless
/// background checker (see [appHasUpdate]'s doc) so a skipped version never
/// shows as "update available" in one but still triggers a notification in
/// the other.
bool isVersionSkipped({
  required String? skippedVersion,
  required String? latestVersion,
}) {
  final skipped = skippedVersion?.trim() ?? '';
  final latest = latestVersion?.trim() ?? '';
  return skipped.isNotEmpty && skipped == latest;
}
