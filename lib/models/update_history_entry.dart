/// A record of one successful download-and-install, for the "update
/// geschiedenis" screen. Purely a local log — never synced or exported —
/// so the user can answer "did X actually update last week?" without
/// digging through Android's own install log.
class UpdateHistoryEntry {
  final String appId;
  final String appName;
  final String? fromVersion;
  final String toVersion;
  final DateTime installedAt;

  const UpdateHistoryEntry({
    required this.appId,
    required this.appName,
    required this.toVersion,
    required this.installedAt,
    this.fromVersion,
  });

  Map<String, dynamic> toJson() => {
    'appId': appId,
    'appName': appName,
    'fromVersion': fromVersion,
    'toVersion': toVersion,
    'installedAt': installedAt.toIso8601String(),
  };

  factory UpdateHistoryEntry.fromJson(Map<String, dynamic> json) =>
      UpdateHistoryEntry(
        appId: json['appId'] as String,
        appName: json['appName'] as String,
        fromVersion: json['fromVersion'] as String?,
        toVersion: json['toVersion'] as String,
        installedAt: DateTime.parse(json['installedAt'] as String),
      );
}
