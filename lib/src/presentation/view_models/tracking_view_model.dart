import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/platform_usage_data_source.dart';
import '../../domain/models/tracking_status.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/usage_repository.dart';

class TrackingState {
  const TrackingState({
    required this.status,
    required this.intervalSeconds,
    required this.idleTimeoutSeconds,
    this.isBusy = false,
  });

  factory TrackingState.initial(UsagePlatform platform) {
    return TrackingState(
      status: TrackingStatus.idle(platform),
      intervalSeconds: 5,
      idleTimeoutSeconds: 60,
    );
  }

  final TrackingStatus status;
  final int intervalSeconds;
  final int idleTimeoutSeconds;
  final bool isBusy;

  TrackingState copyWith({
    TrackingStatus? status,
    int? intervalSeconds,
    int? idleTimeoutSeconds,
    bool? isBusy,
  }) {
    return TrackingState(
      status: status ?? this.status,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      idleTimeoutSeconds: idleTimeoutSeconds ?? this.idleTimeoutSeconds,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class TrackingViewModel extends StateNotifier<TrackingState> {
  TrackingViewModel({
    required UsagePlatform platform,
    required PlatformUsageDataSource platformDataSource,
    required UsageRepository usageRepository,
    required SettingsRepository settingsRepository,
  }) : _platform = platform,
       _platformDataSource = platformDataSource,
       _usageRepository = usageRepository,
       _settingsRepository = settingsRepository,
       super(TrackingState.initial(platform));

  final UsagePlatform _platform;
  final PlatformUsageDataSource _platformDataSource;
  final UsageRepository _usageRepository;
  final SettingsRepository _settingsRepository;

  Timer? _timer;
  DateTime? _lastSampleAt;

  Future<void> loadSettings() async {
    final interval = await _settingsRepository.trackingIntervalSeconds();
    final idleTimeout = await _settingsRepository.idleTimeoutSeconds();
    state = state.copyWith(
      intervalSeconds: interval,
      idleTimeoutSeconds: idleTimeout,
    );
  }

  Future<void> startTracking() async {
    if (_platform != UsagePlatform.windows) {
      state = state.copyWith(
        status: TrackingStatus.error(
          platform: _platform,
          message: _platform == UsagePlatform.android
              ? 'Android usage is read from Usage Access and does not need manual tracking.'
              : 'Usage tracking is not supported on this platform yet.',
        ),
      );
      return;
    }

    await loadSettings();
    _timer?.cancel();
    _lastSampleAt = DateTime.now();
    state = state.copyWith(
      status: TrackingStatus.active(_platform),
      isBusy: false,
    );

    await _sampleActiveWindow();
    _timer = Timer.periodic(
      Duration(seconds: state.intervalSeconds),
      (_) => _sampleActiveWindow(),
    );
  }

  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    await _sampleActiveWindow(force: true);
    _lastSampleAt = null;
    state = state.copyWith(
      status: TrackingStatus.idle(_platform),
      isBusy: false,
    );
  }

  Future<void> updateTrackingInterval(int seconds) async {
    final normalized = seconds.clamp(1, 3600);
    await _settingsRepository.setTrackingIntervalSeconds(normalized);
    state = state.copyWith(intervalSeconds: normalized);
    if (state.status.isTracking) {
      await startTracking();
    }
  }

  Future<void> updateIdleTimeout(int seconds) async {
    final normalized = seconds.clamp(5, 86400);
    await _settingsRepository.setIdleTimeoutSeconds(normalized);
    state = state.copyWith(idleTimeoutSeconds: normalized);
  }

  Future<void> _sampleActiveWindow({bool force = false}) async {
    if (_platform != UsagePlatform.windows) {
      return;
    }

    try {
      final now = DateTime.now();
      final previousSampleAt = _lastSampleAt;
      final currentInfo = await _platformDataSource.getActiveWindowInfo();

      if (previousSampleAt != null &&
          currentInfo != null &&
          (force || now.difference(previousSampleAt).inSeconds > 0) &&
          currentInfo.idleSeconds < state.idleTimeoutSeconds) {
        final durationSeconds = now.difference(previousSampleAt).inSeconds;
        if (durationSeconds > 0) {
          await _usageRepository.insertSession(
            UsageSession(
              id: '${now.microsecondsSinceEpoch}-${currentInfo.processName}',
              platform: UsagePlatform.windows,
              appName: currentInfo.appName,
              processName: currentInfo.processName,
              windowTitle: currentInfo.windowTitle,
              startedAt: previousSampleAt,
              endedAt: now,
              durationSeconds: durationSeconds,
              createdAt: now,
            ),
          );
        }
      }

      _lastSampleAt = now;
      state = state.copyWith(
        status: state.status.copyWith(lastUpdatedAt: now, clearError: true),
      );
    } catch (error) {
      state = state.copyWith(
        status: TrackingStatus.error(
          platform: _platform,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
