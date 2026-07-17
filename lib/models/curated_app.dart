import 'app_source_type.dart';

/// A suggested app bundled with App Updater (shown under "Favoriete apps").
/// Defined in assets/curated_apps.json so new entries can be added there
/// later without touching Dart code.
class CuratedApp {
  final String id;
  final String name;
  final AppSourceType sourceType;
  final String sourceIdentifier;
  final String infoUrl;

  const CuratedApp({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.sourceIdentifier,
    required this.infoUrl,
  });

  factory CuratedApp.fromJson(Map<String, dynamic> json) => CuratedApp(
    id: json['id'] as String,
    name: json['name'] as String,
    sourceType: AppSourceType.fromJson(json['sourceType'] as String),
    sourceIdentifier: json['sourceIdentifier'] as String,
    infoUrl: json['infoUrl'] as String,
  );
}
