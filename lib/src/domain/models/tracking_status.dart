import 'usage_session.dart';

class TrackingStatus {
  const TrackingStatus({
    required this.isTracking,
    required this.platform,
    required this.lastUpdatedAt,
    this.errorMessage,
  });

  factory TrackingStatus.idle(UsagePlatform platform) {
    return TrackingStatus(
      isTracking: false,
      platform: platform,
      lastUpdatedAt: DateTime.now(),
    );
  }

  factory TrackingStatus.active(UsagePlatform platform) {
    return TrackingStatus(
      isTracking: true,
      platform: platform,
      lastUpdatedAt: DateTime.now(),
    );
  }

  factory TrackingStatus.error({
    required UsagePlatform platform,
    required String message,
  }) {
    return TrackingStatus(
      isTracking: false,
      platform: platform,
      lastUpdatedAt: DateTime.now(),
      errorMessage: message,
    );
  }

  final bool isTracking;
  final UsagePlatform platform;
  final DateTime lastUpdatedAt;
  final String? errorMessage;

  bool get isUnsupported => platform == UsagePlatform.unsupported;

  TrackingStatus copyWith({
    bool? isTracking,
    UsagePlatform? platform,
    DateTime? lastUpdatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TrackingStatus(
      isTracking: isTracking ?? this.isTracking,
      platform: platform ?? this.platform,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TrackingStatus &&
            other.isTracking == isTracking &&
            other.platform == platform &&
            other.lastUpdatedAt == lastUpdatedAt &&
            other.errorMessage == errorMessage;
  }

  @override
  int get hashCode =>
      Object.hash(isTracking, platform, lastUpdatedAt, errorMessage);
}
