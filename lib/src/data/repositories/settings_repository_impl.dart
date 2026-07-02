import '../../domain/repositories/settings_repository.dart';
import '../datasources/focus_trace_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._localDataSource);

  static const _trackingIntervalSecondsKey = 'tracking_interval_seconds';
  static const _idleTimeoutSecondsKey = 'idle_timeout_seconds';

  final FocusTraceLocalDataSource _localDataSource;

  @override
  Future<int> trackingIntervalSeconds() async {
    final rawValue = await _localDataSource.readSetting(
      _trackingIntervalSecondsKey,
    );
    return _parsePositiveInt(rawValue) ?? 5;
  }

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) {
    return _localDataSource.writeSetting(
      _trackingIntervalSecondsKey,
      seconds.clamp(1, 3600).toString(),
    );
  }

  @override
  Future<int> idleTimeoutSeconds() async {
    final rawValue = await _localDataSource.readSetting(_idleTimeoutSecondsKey);
    return _parsePositiveInt(rawValue) ?? 60;
  }

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) {
    return _localDataSource.writeSetting(
      _idleTimeoutSecondsKey,
      seconds.clamp(5, 86400).toString(),
    );
  }

  int? _parsePositiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }
}
