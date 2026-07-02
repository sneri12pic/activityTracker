enum UsagePlatform {
  android,
  windows,
  macos,
  ios,
  linux,
  unsupported;

  static UsagePlatform fromName(String? name) {
    return UsagePlatform.values.firstWhere(
      (value) => value.name == name,
      orElse: () => UsagePlatform.unsupported,
    );
  }
}

class UsageSession {
  const UsageSession({
    required this.id,
    required this.platform,
    required this.appName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.createdAt,
    this.packageName,
    this.processName,
    this.windowTitle,
    this.category,
  });

  final String id;
  final UsagePlatform platform;
  final String appName;
  final String? packageName;
  final String? processName;
  final String? windowTitle;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String? category;
  final DateTime createdAt;

  String get appKey => packageName ?? processName ?? appName;

  Duration get duration => Duration(seconds: durationSeconds);

  bool overlaps(DateTime from, DateTime to) {
    final effectiveEnd = endedAt ?? to;
    return startedAt.isBefore(to) && effectiveEnd.isAfter(from);
  }

  UsageSession copyWith({
    String? id,
    UsagePlatform? platform,
    String? appName,
    String? packageName,
    String? processName,
    String? windowTitle,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? category,
    DateTime? createdAt,
  }) {
    return UsageSession(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      processName: processName ?? this.processName,
      windowTitle: windowTitle ?? this.windowTitle,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UsageSession &&
            other.id == id &&
            other.platform == platform &&
            other.appName == appName &&
            other.packageName == packageName &&
            other.processName == processName &&
            other.windowTitle == windowTitle &&
            other.startedAt == startedAt &&
            other.endedAt == endedAt &&
            other.durationSeconds == durationSeconds &&
            other.category == category &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    appName,
    packageName,
    processName,
    windowTitle,
    startedAt,
    endedAt,
    durationSeconds,
    category,
    createdAt,
  );
}
