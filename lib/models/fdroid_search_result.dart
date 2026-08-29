/// One hit from F-Droid's full-text catalog search — see
/// [FdroidSearchService]. Just enough to show in a results list and, on
/// tap, resolve+track [packageId] the same way any other F-Droid source is
/// added.
class FdroidSearchResult {
  final String name;
  final String summary;
  final String packageId;
  final String? iconUrl;

  const FdroidSearchResult({
    required this.name,
    required this.summary,
    required this.packageId,
    this.iconUrl,
  });
}
