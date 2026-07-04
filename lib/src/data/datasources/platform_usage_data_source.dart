
import 'package:flutter/services.dart';

import '../../domain/models/app_usage_summary.dart';

class ActiveWindowInfo {
  const ActiveWindowInfo({
    required this.processName,
    required this.windowTitle,
    required this.idleSeconds,
  });

  final String processName;
  final String windowTitle;
  final double idleSeconds;

  String get appName => processName.isEmpty ? 'Unknown app' : processName;
}

abstract class PlatformUsageDataSource {
  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageSummary>> getTodayUsageStats();

  Future<ActiveWindowInfo?> getActiveWindowInfo();
}

class AndroidUsageDataSource implements PlatformUsageDataSource {
  AndroidUsageDataSource({
    MethodChannel channel = const MethodChannel('focustrace/usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  @override
  Future<void> openUsageAccessSettings() {
    return _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() async {
    final hasAccess = await hasUsageAccess();
    if (!hasAccess) {
      throw PlatformException(
        code: 'USAGE_ACCESS_REQUIRED',
        message: 'Usage Access required to read app usage.',
      );
    }

    final rows = await _channel.invokeListMethod<Object?>('getTodayUsageStats');
    final summaries = (rows ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => _summaryFromAndroidMap(Map<String, Object?>.from(row)))
        .toList();

    final totalSeconds = summaries.fold<int>(
      0,
      (total, summary) => total + summary.totalDurationSeconds,
    );

    return summaries
        .map(
          (summary) => summary.copyWith(
            percentageOfTotal: totalSeconds == 0
                ? 0
                : summary.totalDurationSeconds / totalSeconds,
          ),
        )
        .toList();
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async {
    throw UnsupportedError(
      'Active window tracking is not available on Android.',
    );
  }

  AppUsageSummary _summaryFromAndroidMap(Map<String, Object?> row) {
    final durationMs = (row['totalTimeInForegroundMs'] as num?)?.toInt() ?? 0;
    final lastUsedMs = (row['lastTimeUsedMs'] as num?)?.toInt();
    final packageName = row['packageName'] as String?;
    final appName = row['appName'] as String? ?? packageName ?? 'Unknown app';

    return AppUsageSummary(
      appName: appName,
      packageName: packageName,
      totalDurationSeconds: Duration(milliseconds: durationMs).inSeconds,
      percentageOfTotal: 0,
      lastUsedAt: lastUsedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
      iconBytes: row['iconBytes'] as Uint8List?,
    );
  }
}

class WindowsUsageDataSource implements PlatformUsageDataSource {
  WindowsUsageDataSource({
    MethodChannel channel = const MethodChannel('focustrace/windows_usage'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() {
    throw UnsupportedError(
      'Windows summaries are calculated from locally tracked sessions.',
    );
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async {
    final row = await _channel.invokeMapMethod<String, Object?>(
      'getActiveWindowInfo',
    );
    if (row == null || row['hasWindow'] != true) {
      return null;
    }
    return ActiveWindowInfo(
      processName: row['processName'] as String? ?? '',
      windowTitle: row['windowTitle'] as String? ?? '',
      idleSeconds: (row['idleSeconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UnsupportedPlatformUsageDataSource implements PlatformUsageDataSource {
  const UnsupportedPlatformUsageDataSource();

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<void> openUsageAccessSettings() {
    throw UnsupportedError('Usage permissions are not available.');
  }

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() {
    throw UnsupportedError('Usage tracking is not supported on this platform.');
  }

  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() {
    throw UnsupportedError('Active window tracking is not supported.');
  }
}
