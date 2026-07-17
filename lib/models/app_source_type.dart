enum AppSourceType {
  github,
  fdroid,
  direct;

  static AppSourceType fromJson(String value) => AppSourceType.values
      .firstWhere((t) => t.name == value, orElse: () => AppSourceType.direct);

  String toJson() => name;
}
