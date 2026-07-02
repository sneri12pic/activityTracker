abstract class SettingsRepository {
  Future<int> trackingIntervalSeconds();

  Future<void> setTrackingIntervalSeconds(int seconds);

  Future<int> idleTimeoutSeconds();

  Future<void> setIdleTimeoutSeconds(int seconds);
}
