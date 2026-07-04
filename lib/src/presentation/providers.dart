import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/usage_aggregation_service.dart';
import '../data/datasources/focus_trace_local_data_source.dart';
import '../data/datasources/platform_usage_data_source.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/repositories/usage_repository_impl.dart';
import '../domain/models/usage_session.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/usage_repository.dart';
import 'view_models/dashboard_view_model.dart';
import 'view_models/onboarding_view_model.dart';
import 'view_models/restrictions_view_model.dart';
import 'view_models/settings_view_model.dart';
import 'view_models/tracking_view_model.dart';

final usagePlatformProvider = Provider<UsagePlatform>((ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return UsagePlatform.android;
    case TargetPlatform.windows:
      return UsagePlatform.windows;
    case TargetPlatform.iOS:
      return UsagePlatform.ios;
    case TargetPlatform.macOS:
      return UsagePlatform.macos;
    case TargetPlatform.linux:
      return UsagePlatform.linux;
    case TargetPlatform.fuchsia:
      return UsagePlatform.unsupported;
  }
});

final usageAggregationServiceProvider = Provider<UsageAggregationService>(
  (ref) => const UsageAggregationService(),
);

final localDataSourceProvider = Provider<FocusTraceLocalDataSource>(
  (ref) => SqfliteFocusTraceLocalDataSource(),
);

final platformDataSourceProvider = Provider<PlatformUsageDataSource>((ref) {
  switch (ref.watch(usagePlatformProvider)) {
    case UsagePlatform.android:
      return AndroidUsageDataSource();
    case UsagePlatform.windows:
      return WindowsUsageDataSource();
    case UsagePlatform.macos:
    case UsagePlatform.ios:
    case UsagePlatform.linux:
    case UsagePlatform.unsupported:
      return const UnsupportedPlatformUsageDataSource();
  }
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepositoryImpl(
    platform: ref.watch(usagePlatformProvider),
    localDataSource: ref.watch(localDataSourceProvider),
    platformDataSource: ref.watch(platformDataSourceProvider),
    aggregationService: ref.watch(usageAggregationServiceProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(localDataSourceProvider));
});

final onboardingViewModelProvider =
    StateNotifierProvider<OnboardingViewModel, OnboardingState>((ref) {
      final viewModel = OnboardingViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
      );
      viewModel.load();
      return viewModel;
    });

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
      final viewModel = DashboardViewModel(
        usageRepository: ref.watch(usageRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        platform: ref.watch(usagePlatformProvider),
        aggregationService: ref.watch(usageAggregationServiceProvider),
      );
      viewModel.loadTodayUsage();
      return viewModel;
    });

final trackingViewModelProvider =
    StateNotifierProvider<TrackingViewModel, TrackingState>((ref) {
      final viewModel = TrackingViewModel(
        platform: ref.watch(usagePlatformProvider),
        platformDataSource: ref.watch(platformDataSourceProvider),
        usageRepository: ref.watch(usageRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
      );
      viewModel.loadSettings();
      return viewModel;
    });

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
      final viewModel = SettingsViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        usageRepository: ref.watch(usageRepositoryProvider),
      );
      viewModel.load();
      return viewModel;
    });

final restrictionsViewModelProvider =
    StateNotifierProvider<RestrictionsViewModel, RestrictionsState>((ref) {
      final viewModel = RestrictionsViewModel(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        platformDataSource: ref.watch(platformDataSourceProvider),
        platform: ref.watch(usagePlatformProvider),
      );
      viewModel.load();
      return viewModel;
    });
