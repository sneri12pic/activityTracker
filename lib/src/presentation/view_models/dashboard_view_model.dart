import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/usage_aggregation_service.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';
import '../../domain/repositories/usage_repository.dart';

class DashboardState {
  const DashboardState({
    required this.platform,
    required this.summaries,
    required this.totalDurationSeconds,
    required this.hasUsageAccess,
    this.isLoading = false,
    this.errorMessage,
  });

  factory DashboardState.initial(UsagePlatform platform) {
    return DashboardState(
      platform: platform,
      summaries: const <AppUsageSummary>[],
      totalDurationSeconds: 0,
      hasUsageAccess: platform != UsagePlatform.android,
      isLoading: true,
    );
  }

  final UsagePlatform platform;
  final List<AppUsageSummary> summaries;
  final int totalDurationSeconds;
  final bool hasUsageAccess;
  final bool isLoading;
  final String? errorMessage;

  DashboardState copyWith({
    List<AppUsageSummary>? summaries,
    int? totalDurationSeconds,
    bool? hasUsageAccess,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      platform: platform,
      summaries: summaries ?? this.summaries,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      hasUsageAccess: hasUsageAccess ?? this.hasUsageAccess,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel({
    required UsageRepository usageRepository,
    required UsagePlatform platform,
    UsageAggregationService aggregationService =
        const UsageAggregationService(),
  }) : _usageRepository = usageRepository,
       _aggregationService = aggregationService,
       super(DashboardState.initial(platform));

  final UsageRepository _usageRepository;
  final UsageAggregationService _aggregationService;

  Future<void> loadTodayUsage({bool showLoading = true}) async {
    // ponytail: showLoading=false skips the spinner so the 5s auto-refresh
    // doesn't flicker the dashboard while tracking.
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final hasAccess = await _usageRepository.hasUsageAccess();
      if (state.platform == UsagePlatform.android && !hasAccess) {
        state = state.copyWith(
          summaries: const <AppUsageSummary>[],
          totalDurationSeconds: 0,
          hasUsageAccess: false,
          isLoading: false,
        );
        return;
      }

      final summaries = await _usageRepository.getTodaySummaries();
      state = state.copyWith(
        summaries: summaries,
        totalDurationSeconds: _aggregationService.totalDurationSeconds(
          summaries,
        ),
        hasUsageAccess: hasAccess,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> refresh() => loadTodayUsage();

  Future<void> refreshSilently() => loadTodayUsage(showLoading: false);

  Future<void> checkPermission() async {
    final hasAccess = await _usageRepository.hasUsageAccess();
    state = state.copyWith(hasUsageAccess: hasAccess);
  }

  Future<void> openPermissionSettings() async {
    await _usageRepository.openUsageAccessSettings();
  }

  Future<void> clearData() async {
    await _usageRepository.clearAllData();
    await loadTodayUsage();
  }
}
