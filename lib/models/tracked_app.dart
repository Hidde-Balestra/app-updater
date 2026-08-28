import 'app_source_type.dart';

class TrackedApp {
  final String id;
  final String name;
  final AppSourceType sourceType;
  final String sourceIdentifier;
  final bool isCurated;
  final String? installedVersion;

  /// Android package id (e.g. "com.example.app"), used to look up the
  /// actually-installed version straight from the device's package manager
  /// during a device scan. Optional — apps added without one simply aren't
  /// eligible for that sync and fall back to the manual "mark installed"
  /// flow that already runs after a download-and-install.
  final String? packageName;

  const TrackedApp({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.sourceIdentifier,
    this.isCurated = false,
    this.installedVersion,
    this.packageName,
  });

  TrackedApp copyWith({
    String? name,
    String? installedVersion,
    String? packageName,
  }) => TrackedApp(
    id: id,
    name: name ?? this.name,
    sourceType: sourceType,
    sourceIdentifier: sourceIdentifier,
    isCurated: isCurated,
    installedVersion: installedVersion ?? this.installedVersion,
    packageName: packageName ?? this.packageName,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sourceType': sourceType.toJson(),
    'sourceIdentifier': sourceIdentifier,
    'isCurated': isCurated,
    'installedVersion': installedVersion,
    'packageName': packageName,
  };

  factory TrackedApp.fromJson(Map<String, dynamic> json) => TrackedApp(
    id: json['id'] as String,
    name: json['name'] as String,
    sourceType: AppSourceType.fromJson(json['sourceType'] as String),
    sourceIdentifier: json['sourceIdentifier'] as String,
    isCurated: json['isCurated'] as bool? ?? false,
    installedVersion: json['installedVersion'] as String?,
    packageName: json['packageName'] as String?,
  );

  /// Two initials used for the avatar, e.g. "MijnBudget" -> "MB".
  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Short human-readable label for the source, e.g. "GitHub" or the raw
  /// package id / URL for F-Droid and direct sources.
  String get sourceLabel {
    switch (sourceType) {
      case AppSourceType.github:
        return 'github.com/$sourceIdentifier';
      case AppSourceType.fdroid:
        return sourceIdentifier;
      case AppSourceType.direct:
        return sourceIdentifier;
    }
  }
}
