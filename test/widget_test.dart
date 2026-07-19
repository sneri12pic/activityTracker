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
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          appLanguageRepositoryProvider.overrideWithValue(
            _FakeAppLanguageRepository(),
          ),
        ],
        child: const FocusTraceApp(),
      ),
    );

    // The bubble chart's pulsing background animates forever, so
    // pumpAndSettle would never settle; pump fixed frames instead. Each
    // async layer (language load, onboarding gate, usage data) needs a frame.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Usage Bubbles'), findsOneWidget);
    expect(find.text('Most used of all time'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('editor.exe'), findsNothing);
    expect(find.text('Launches: 3'), findsOneWidget);
    expect(find.text('1h 15m'), findsWidgets);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byType(UsageBubble));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Productivity'), findsOneWidget);

    // Let the tooltip auto-dismiss so no timers are pending at test end.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Productivity'), findsNothing);
  });

  testWidgets('language picker applies and persists locale immediately', (
    tester,
  ) async {
    final languageRepository = _FakeAppLanguageRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usagePlatformProvider.overrideWithValue(UsagePlatform.windows),
          usageRepositoryProvider.overrideWithValue(_FakeUsageRepository()),
          platformDataSourceProvider.overrideWithValue(
            _FakePlatformDataSource(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          appLanguageRepositoryProvider.overrideWithValue(languageRepository),
        ],
        child: const FocusTraceApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Route pushes and dialogs need one pump to mount plus one to animate.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Español'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(languageRepository.language, AppLanguage.spanish);
    final settingsContext = tester.element(find.byType(SettingsScreen));
    expect(Localizations.localeOf(settingsContext).languageCode, 'es');
  });
}

class _FakeAppLanguageRepository implements AppLanguageRepository {
  AppLanguage language = AppLanguage.english;

  @override
  Future<AppLanguage> appLanguage() async => language;

  @override
  Future<void> setAppLanguage(AppLanguage language) async {
    this.language = language;
  }
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
        launchCount: 3,
      ),
    ];
  }

  @override
  Future<List<AppUsageSummary>> getDailySummaries(DateTime day) async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getAllTimeSummaries() async => const [
    AppUsageSummary(
      appName: 'Archive',
      processName: 'archive.exe',
      totalDurationSeconds: 7200,
      percentageOfTotal: 1,
      launchCount: 5,
    ),
  ];

  @override
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  }) async => const <UsageSession>[];

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> insertSession(UsageSession session) async {}

  @override
  Future<void> openUsageAccessSettings() async {}
}

class _FakePlatformDataSource implements PlatformUsageDataSource {
  @override
  Future<ActiveWindowInfo?> getActiveWindowInfo() async => null;

  @override
  Future<List<AppUsageSummary>> getInstalledApps() async =>
      const <AppUsageSummary>[];

  @override
  Future<List<AppUsageSummary>> getTodayUsageStats() async =>
      const <AppUsageSummary>[];

  @override
  Future<bool> hasOverlayPermission() async => true;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestNotificationsPermission() async {}

  @override
  Future<void> syncRestrictions(String json) async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  int _trackingIntervalSeconds = 5;
  int _idleTimeoutSeconds = 60;
  final List<String> _excludedApps = [];
  final Set<String> _hiddenAppsToday = {};
  bool _onboardingCompleted = true;

  @override
  Future<List<String>> excludedApps() async => List.of(_excludedApps);

  @override
  Future<void> addExcludedApp(String appKey) async {
    if (!_excludedApps.contains(appKey)) {
      _excludedApps.add(appKey);
    }
  }

  @override
  Future<void> removeExcludedApp(String appKey) async {
    _excludedApps.remove(appKey);
  }

  @override
  Future<Set<String>> hiddenAppsForToday() async => Set.of(_hiddenAppsToday);

  @override
  Future<void> hideAppForToday(String appKey) async {
    _hiddenAppsToday.add(appKey);
  }

  @override
  Future<bool> onboardingCompleted() async => _onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _onboardingCompleted = completed;
  }

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

  @override
  Future<List<RestrictionRule>> restrictionRules() async =>
      const <RestrictionRule>[];

  @override
  Future<void> saveRestrictionRule(RestrictionRule rule) async {}

  @override
  Future<void> removeRestrictionRule(
    String appKey,
    RestrictionRuleType type,
  ) async {}
}
