/// Whether [latestVersion] should be offered as an update over
/// [installedVersion]. Deliberately a plain inequality check rather than
/// semver parsing: tracked apps don't all follow semver (tags like
/// "V.0.8.0" have been seen in the wild), so a strict parser would be more
/// likely to misfire than a simple "is it different" check.
bool isUpdateAvailable({required String? installedVersion, required String? latestVersion}) {
  if (latestVersion == null) return false;
  if (installedVersion == null) return true;
  return installedVersion.trim() != latestVersion.trim();
}
