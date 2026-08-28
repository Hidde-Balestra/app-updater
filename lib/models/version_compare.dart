import 'app_source_type.dart';

/// Whether [latestVersion] should be offered as an update over
/// [installedVersion]. Deliberately a plain inequality check rather than
/// semver parsing: tracked apps don't all follow semver (tags like
/// "V.0.8.0" have been seen in the wild), so a strict parser would be more
/// likely to misfire than a simple "is it different" check.
bool isUpdateAvailable({
  required String? installedVersion,
  required String? latestVersion,
}) {
  if (latestVersion == null) return false;
  if (installedVersion == null) return true;
  return installedVersion.trim() != latestVersion.trim();
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
