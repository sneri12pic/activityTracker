import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/utils/duration_format.dart';
import '../../domain/models/usage_session.dart';
import '../providers.dart';
import '../widgets/permission_card.dart';
import '../widgets/tracking_status_banner.dart';
import 'settings_screen.dart';
import 'usage_bubble_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final trackingState = ref.watch(trackingViewModelProvider);
    final trackingViewModel = ref.read(trackingViewModelProvider.notifier);

    // Reload the dashboard on every tracking sample so the total climbs live.
    ref.listen(trackingViewModelProvider, (previous, next) {
      if (next.status.lastUpdatedAt != previous?.status.lastUpdatedAt) {
        dashboardViewModel.refreshSilently();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusTrace'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: dashboardState.isLoading
                ? null
                : dashboardViewModel.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: dashboardViewModel.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (dashboardState.errorMessage == null &&
                !dashboardState.isLoading &&
                dashboardState.summaries.isNotEmpty) ...[
              UsageBubbleScreen(summaries: dashboardState.summaries),
              const SizedBox(height: 12),
            ],
            _TodayTotal(
              totalSeconds: dashboardState.totalDurationSeconds,
              platform: dashboardState.platform,
            ),
            const SizedBox(height: 12),
            PermissionCard(
              platform: dashboardState.platform,
              hasUsageAccess: dashboardState.hasUsageAccess,
              onOpenSettings: dashboardViewModel.openPermissionSettings,
              onRecheck: dashboardViewModel.checkPermission,
            ),
            if (dashboardState.platform == UsagePlatform.windows) ...[
              const SizedBox(height: 12),
              TrackingStatusBanner(status: trackingState.status),
              const SizedBox(height: 12),
              _TrackingControls(
                isTracking: trackingState.status.isTracking,
                isBusy: trackingState.isBusy,
                onStart: () async {
                  await trackingViewModel.startTracking();
                  await dashboardViewModel.refresh();
                },
                onStop: () async {
                  await trackingViewModel.stopTracking();
                  await dashboardViewModel.refresh();
                },
              ),
            ],
            if (dashboardState.platform != UsagePlatform.android &&
                dashboardState.platform != UsagePlatform.windows) ...[
              const SizedBox(height: 12),
              const _UnsupportedPanel(),
            ],
            const SizedBox(height: 16),
            if (dashboardState.errorMessage != null)
              _ErrorPanel(
                message: dashboardState.errorMessage!,
                onRetry: dashboardViewModel.refresh,
              )
            else if (dashboardState.isLoading)
              const _LoadingPanel()
            else if (dashboardState.summaries.isEmpty)
              const _EmptyPanel(),
          ],
        ),
      ),
    );
  }
}

class _TodayTotal extends StatelessWidget {
  const _TodayTotal({required this.totalSeconds, required this.platform});

  final int totalSeconds;
  final UsagePlatform platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today tracked',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DurationFormat.compact(Duration(seconds: totalSeconds)),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            platform == UsagePlatform.android
                ? 'Usage Access required to read app usage.'
                : platform == UsagePlatform.windows
                ? 'Tracking runs only while FocusTrace is open.'
                : 'This platform is not supported in the MVP.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({
    required this.isTracking,
    required this.isBusy,
    required this.onStart,
    required this.onStop,
  });

  final bool isTracking;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isBusy ? null : (isTracking ? onStop : onStart),
      icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
      label: Text(isTracking ? 'Stop Tracking' : 'Start Tracking'),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('No usage recorded for today.')),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnsupportedPanel extends StatelessWidget {
  const _UnsupportedPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'FocusTrace MVP supports Android and Windows. Other platforms can be added later through isolated platform data sources.',
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
