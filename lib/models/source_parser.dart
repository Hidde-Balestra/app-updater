/// Turns free-form user input (a pasted URL or a bare id) into the
/// canonical source identifier each service expects. Kept as small pure
/// functions so they're easy to unit test independently of the network
/// calls and widgets that use them.
library;

/// GitHub: accepts "owner/repo", a github.com URL, or a releases URL and
/// returns "owner/repo", or null if it can't be parsed.
String? parseGithubSource(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains('://')) {
    final parts = trimmed.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0]}/${parts[1]}';
    return null;
  }

  try {
    final uri = Uri.parse(trimmed);
    if (uri.host != 'github.com' && uri.host != 'www.github.com') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    return '${segments[0]}/${segments[1]}';
  } catch (_) {
    return null;
  }
}

/// F-Droid: accepts a bare package id or an f-droid.org packages URL and
/// returns the package id, or null if it can't be parsed.
String? parseFdroidSource(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains('://')) return trimmed;

  try {
    final uri = Uri.parse(trimmed);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final idx = segments.indexOf('packages');
    if (idx != -1 && idx + 1 < segments.length) return segments[idx + 1];
    return null;
  } catch (_) {
    return null;
  }
}

/// Derives a reasonable default display name from a resolved identifier
/// when the user leaves the optional display-name field empty.
String defaultNameFor({
  required String identifierKind,
  required String identifier,
}) {
  switch (identifierKind) {
    case 'github':
      final parts = identifier.split('/');
      return parts.length == 2 ? parts[1] : identifier;
    case 'fdroid':
      return identifier;
    default:
      final fileName = identifier.split('/').last;
      return fileName.toLowerCase().endsWith('.apk')
          ? fileName.substring(0, fileName.length - 4)
          : fileName;
  }
}
