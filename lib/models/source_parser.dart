/// Turns free-form user input (a pasted URL or a bare id) into the
/// canonical source identifier each service expects. Kept as small pure
/// functions so they're easy to unit test independently of the network
/// calls and widgets that use them.
library;

import 'app_source_type.dart';

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

/// GitLab: accepts "namespace/project" (nested groups allowed, e.g.
/// "group/subgroup/project"), a gitlab.com project URL, or a releases URL,
/// and returns the "namespace/project" path, or null if it can't be parsed.
String? parseGitlabSource(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains('://')) {
    final parts = trimmed.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return parts.join('/');
    return null;
  }

  try {
    final uri = Uri.parse(trimmed);
    if (uri.host != 'gitlab.com' && uri.host != 'www.gitlab.com') return null;
    var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final dashIndex = segments.indexOf('-');
    if (dashIndex != -1) segments = segments.sublist(0, dashIndex);
    if (segments.length < 2) return null;
    return segments.join('/');
  } catch (_) {
    return null;
  }
}

/// Codeberg: accepts "owner/repo", a codeberg.org repo URL, or a releases
/// URL and returns "owner/repo", or null if it can't be parsed.
String? parseCodebergSource(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains('://')) {
    final parts = trimmed.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0]}/${parts[1]}';
    return null;
  }

  try {
    final uri = Uri.parse(trimmed);
    if (uri.host != 'codeberg.org' && uri.host != 'www.codeberg.org') {
      return null;
    }
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

/// Accrescent: accepts a bare Android application id or an
/// `accrescent.app/app/{id}` deep link and returns the application id, or
/// null if it can't be parsed.
String? parseAccrescentSource(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains('://')) return trimmed;

  try {
    final uri = Uri.parse(trimmed);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final idx = segments.indexOf('app');
    if (idx != -1 && idx + 1 < segments.length) return segments[idx + 1];
    return null;
  } catch (_) {
    return null;
  }
}

/// Guesses which [AppSourceType] a pasted URL belongs to, so the "Online app"
/// tab can select it automatically instead of making the user pick a type
/// before pasting. Only recognizes an unambiguous URL (a host it knows, or
/// a direct ".apk" link) — a bare "owner/repo"-shaped string with no host is
/// deliberately left undetected (returns null) rather than guessing, since
/// that exact shape is valid for GitHub, GitLab *and* Codeberg alike and a
/// wrong guess would be worse than leaving the user's current selection
/// alone.
AppSourceType? detectSourceType(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains('://')) return null;

  if (trimmed.toLowerCase().endsWith('.apk')) return AppSourceType.direct;

  try {
    final host = Uri.parse(trimmed).host.toLowerCase();
    final withoutWww = host.startsWith('www.') ? host.substring(4) : host;
    return switch (withoutWww) {
      'github.com' => AppSourceType.github,
      'gitlab.com' => AppSourceType.gitlab,
      'codeberg.org' => AppSourceType.codeberg,
      'f-droid.org' => AppSourceType.fdroid,
      'accrescent.app' => AppSourceType.accrescent,
      _ => null,
    };
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
    case 'gitlab':
      final parts = identifier.split('/');
      return parts.isNotEmpty ? parts.last : identifier;
    case 'codeberg':
      final parts = identifier.split('/');
      return parts.length == 2 ? parts[1] : identifier;
    case 'fdroid':
    case 'accrescent':
      return identifier;
    default:
      final fileName = identifier.split('/').last;
      return fileName.toLowerCase().endsWith('.apk')
          ? fileName.substring(0, fileName.length - 4)
          : fileName;
  }
}
