import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focustrace/focus_trace.dart';

void main() {
  testWidgets('dashboard renders usage summaries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(_FakeUsageRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('FocusTrace'), findsOneWidget);
    expect(find.text('Usage Bubbles'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('1h 15m'), findsWidgets);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byType(UsageBubble));
    await tester.pumpAndSettle();

    expect(find.text('Productivity'), findsOneWidget);
  });
}

class _FakeUsageRepository implements UsageRepository {
  @override
  Future<void> clearAllData() async {}

  @override
  Future<List<AppUsageSummary>> getTodaySummaries() async {
    return [
      const AppUsageSummary(
        appName: 'Editor',
        processName: 'editor.exe',
        totalDurationSeconds: 4500,
        percentageOfTotal: 1,
      ),
    ];
  }

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> insertSession(UsageSession session) async {}

  @override
  Future<void> openUsageAccessSettings() async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  int _trackingIntervalSeconds = 5;
  int _idleTimeoutSeconds = 60;

  @override
  Future<int> idleTimeoutSeconds() async => _idleTimeoutSeconds;

  @override
  Future<void> setIdleTimeoutSeconds(int seconds) async {
    _idleTimeoutSeconds = seconds;
  }

  @override
  Future<void> setTrackingIntervalSeconds(int seconds) async {
    _trackingIntervalSeconds = seconds;
  }

  @override
  Future<int> trackingIntervalSeconds() async => _trackingIntervalSeconds;
}
