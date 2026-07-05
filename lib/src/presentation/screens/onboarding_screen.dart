import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/utils/duration_format.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_session.dart';
import '../providers.dart';
import '../widgets/permission_card.dart';
import 'dashboard_screen.dart';
import 'restriction_editor_sheet.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingViewModelProvider);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.isCompleted) {
      return const DashboardScreen();
    }
    return const OnboardingScreen();
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingViewModelProvider);
    final onboardingViewModel = ref.read(onboardingViewModelProvider.notifier);
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final summaries = _filteredSummaries(dashboardState.summaries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusTrace setup'),
        actions: [
          TextButton(
            onPressed: onboardingState.isSaving
                ? null
                : () => onboardingViewModel.skip(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: dashboardViewModel.refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Pick apps you want to use less',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a daily target for selected apps. This is a soft block: if something is urgent, you can unblock the app from FocusTrace.',
            ),
            const SizedBox(height: 16),
            PermissionCard(
              platform: dashboardState.platform,
              hasUsageAccess: dashboardState.hasUsageAccess,
              onOpenSettings: dashboardViewModel.openPermissionSettings,
              onRecheck: dashboardViewModel.checkPermission,
            ),
            if (dashboardState.platform == UsagePlatform.android &&
                !dashboardState.hasUsageAccess)
              const SizedBox(height: 12),
            _OnboardingControlsSection(
              limitMinutes: onboardingState.limitMinutes,
              isEnabled: !onboardingState.isSaving,
              onSearchChanged: (value) => setState(() => _query = value),
              onLimitChanged: onboardingViewModel.updateLimitMinutes,
            ),
            const SizedBox(height: 12),
            if (dashboardState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (dashboardState.summaries.isEmpty)
              const _OnboardingInfoCard(
                title: 'No apps to choose yet',
                body:
                    'FocusTrace needs current usage data before it can show apps here. You can skip setup and add restrictions later from Settings.',
              )
            else if (summaries.isEmpty)
              const _OnboardingInfoCard(
                title: 'No matching apps',
                body: 'Try a different search term.',
              )
            else
              for (final summary in summaries)
                _SelectableAppTile(
                  summary: summary,
                  isSelected: onboardingState.selectedAppKeys.contains(
                    summary.appKey,
                  ),
                  onChanged: onboardingState.isSaving
                      ? null
                      : (_) => onboardingViewModel.toggleApp(summary.appKey),
                ),
            if (onboardingState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                onboardingState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  onboardingState.isSaving ||
                      onboardingState.selectedAppKeys.isEmpty
                  ? null
                  : () => _completeOnboarding(dashboardState.summaries),
              icon: const Icon(Icons.check),
              label: const Text('Start soft blocks'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onboardingState.isSaving
                  ? null
                  : () => onboardingViewModel.skip(),
              child: const Text('Choose later'),
            ),
          ],
        ),
      ),
    );
  }

  List<AppUsageSummary> _filteredSummaries(List<AppUsageSummary> summaries) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? summaries.toList()
        : summaries
              .where(
                (summary) =>
                    summary.appName.toLowerCase().contains(query) ||
                    summary.appKey.toLowerCase().contains(query),
              )
              .toList();
    return visible..sort(
      (first, second) =>
          second.totalDurationSeconds.compareTo(first.totalDurationSeconds),
    );
  }

  Future<void> _completeOnboarding(List<AppUsageSummary> summaries) async {
    await ref
        .read(onboardingViewModelProvider.notifier)
        .completeWithSoftBlocks(summaries);
    if (!ref.read(onboardingViewModelProvider).isCompleted) {
      return;
    }
    await ref.read(restrictionsViewModelProvider.notifier).load();
    if (mounted) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }
}

class _OnboardingControlsSection extends StatelessWidget {
  const _OnboardingControlsSection({
    required this.limitMinutes,
    required this.isEnabled,
    required this.onSearchChanged,
    required this.onLimitChanged,
  });

  final int limitMinutes;
  final bool isEnabled;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onLimitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchBarBox(onChanged: onSearchChanged),
        const SizedBox(height: 12),
        _DailyTargetTile(
          limitMinutes: limitMinutes,
          isEnabled: isEnabled,
          onChanged: onLimitChanged,
        ),
      ],
    );
  }
}

class _SearchBarBox extends StatelessWidget {
  const _SearchBarBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search apps',
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.6,
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SelectableAppTile extends StatelessWidget {
  const _SelectableAppTile({
    required this.summary,
    required this.isSelected,
    required this.onChanged,
  });

  final AppUsageSummary summary;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        secondary: _AppIcon(summary: summary),
        title: Text(
          summary.appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DurationFormat.compact(summary.totalDuration)} today',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class _DailyTargetTile extends StatelessWidget {
  const _DailyTargetTile({
    required this.limitMinutes,
    required this.isEnabled,
    required this.onChanged,
  });

  final int limitMinutes;
  final bool isEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.16),
                child: Icon(
                  Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text('Daily target'),
              subtitle: Text('$limitMinutes minutes per day'),
            ),
            Slider(
              value: limitMinutes.toDouble(),
              min: 5,
              max: 480,
              divisions: 95,
              label: '${limitMinutes}m',
              onChanged: isEnabled ? (value) => onChanged(value.round()) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.summary});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final iconBytes = summary.iconBytes;
    if (iconBytes != null) {
      return ClipOval(
        child: Image.memory(
          Uint8List.fromList(iconBytes),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return CircleAvatar(
      child: Text(
        summary.appName.isEmpty ? '?' : summary.appName[0].toUpperCase(),
      ),
    );
  }
}

class _OnboardingInfoCard extends StatelessWidget {
  const _OnboardingInfoCard({required this.title, required this.body});

  final String title;
  final String body;

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
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
