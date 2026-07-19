import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';
import '../screens/restriction_editor_sheet.dart';

const _sheetColor = Color(0xFF0D111A);

class SummaryTile extends ConsumerWidget {
  const SummaryTile(this.summary, {required this.isToday, super.key});

  final AppUsageSummary summary;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final percentage = (summary.percentageOfTotal * 100).clamp(0, 100);
    final restrictionState = ref.watch(restrictionsViewModelProvider);
    final isBlocked =
        isToday &&
        isAppBlocked(
          appKey: summary.appKey,
          rules: restrictionState.rules,
          now: DateTime.now(),
          usageSecondsToday: summary.totalDurationSeconds,
        );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSessionDetails(context, ref),
        onLongPress: isToday ? () => _showActions(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (summary.iconBytes != null)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipOval(
                          child: Image.memory(
                            summary.iconBytes!,
                            width: 36,
                            height: 36,
                            cacheWidth: 108,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                        if (isBlocked) const _LockBadge(),
                      ],
                    )
                  else
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          child: Text(
                            summary.appName.isEmpty
                                ? '?'
                                : summary.appName[0].toUpperCase(),
                          ),
                        ),
                        if (isBlocked) const _LockBadge(),
                      ],
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (summary.launchCount > 0)
                          Text(
                            context.l10n.summaryLaunchCount(
                              summary.launchCount,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.l10n.compactDuration(summary.totalDuration),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.l10n.percentageValue(
                          percentage.toStringAsFixed(0),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: summary.percentageOfTotal.clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSessionDetails(BuildContext context, WidgetRef ref) async {
    final platform = ref.read(dashboardViewModelProvider).platform;
    final sessions = await ref
        .read(dashboardViewModelProvider.notifier)
        .topSessionsForApp(summary);
    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _sheetColor,
      builder: (context) => _SessionDetailsSheet(
        summary: summary,
        sessions: sessions,
        platform: platform,
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final restrictionState = ref.read(restrictionsViewModelProvider);
    final isBlocked = isAppBlocked(
      appKey: summary.appKey,
      rules: restrictionState.rules,
      now: DateTime.now(),
      usageSecondsToday: summary.totalDurationSeconds,
    );
    final action = await showModalBottomSheet<_SummaryAction>(
      context: context,
      backgroundColor: _sheetColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: summary.appName),
            if (isBlocked)
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: Text(context.l10n.actionUnblockNow),
                subtitle: Text(context.l10n.actionUnblockNowDescription),
                onTap: () =>
                    Navigator.of(context).pop(_SummaryAction.unblockNow),
              ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.l10n.actionRestrictApp),
              subtitle: Text(context.l10n.actionRestrictAppDescription),
              onTap: () => Navigator.of(context).pop(_SummaryAction.restrict),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(context.l10n.actionRemoveFromToday),
              subtitle: Text(context.l10n.actionRemoveFromTodayDescription),
              onTap: () =>
                  Navigator.of(context).pop(_SummaryAction.removeFromToday),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(context.l10n.actionExcludeFromTracking),
              subtitle: Text(context.l10n.actionExcludeFromTrackingDescription),
              onTap: () => Navigator.of(context).pop(_SummaryAction.exclude),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) {
      return;
    }

    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    switch (action) {
      case _SummaryAction.unblockNow:
        await ref
            .read(restrictionsViewModelProvider.notifier)
            .unblockAppNow(
              appKey: summary.appKey,
              usageSecondsToday: summary.totalDurationSeconds,
            );
      case _SummaryAction.restrict:
        final rule = await showRestrictionEditor(
          context,
          appKey: summary.appKey,
          appName: summary.appName,
        );
        if (rule == null || !context.mounted) {
          return;
        }
        await ref.read(restrictionsViewModelProvider.notifier).saveRule(rule);
        if (context.mounted) {
          await promptRestrictionPermissionsIfNeeded(context, ref);
        }
      case _SummaryAction.removeFromToday:
        await dashboardViewModel.hideAppForToday(summary);
      case _SummaryAction.exclude:
        final confirmed = await _confirmExclude(context);
        if (confirmed) {
          await dashboardViewModel.excludeApp(summary);
          // Keep the settings screen's excluded-apps list in sync.
          await ref.read(settingsViewModelProvider.notifier).load();
        }
    }
  }

  Future<bool> _confirmExclude(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(context.l10n.excludeAppDialogTitle(summary.appName)),
              content: Text(context.l10n.excludeAppDialogBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.actionExclude),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

enum _SummaryAction { unblockNow, restrict, removeFromToday, exclude }

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -2,
      bottom: -2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0D111A), width: 1.5),
        ),
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.lock, size: 10, color: Colors.white),
        ),
      ),
    );
  }
}

class _SessionDetailsSheet extends StatelessWidget {
  const _SessionDetailsSheet({
    required this.summary,
    required this.sessions,
    required this.platform,
  });

  final AppUsageSummary summary;
  final List<UsageSession> sessions;
  final UsagePlatform platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: summary.appName,
            subtitle: context.l10n.sessionTotal(
              context.l10n.compactDuration(summary.totalDuration),
            ),
          ),
          if (platform != UsagePlatform.windows)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(
                context.l10n.sessionDetailsUnavailable,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(
                context.l10n.sessionNoneRecorded,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                context.l10n.sessionLongestTitle,
                style: theme.textTheme.labelLarge,
              ),
            ),
            for (final session in sessions)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule, size: 20),
                title: Text(_sessionLabel(context, session)),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _sessionLabel(BuildContext context, UsageSession session) {
    final start = _clock(context, session.startedAt);
    final duration = context.l10n.compactDuration(session.duration);
    final endedAt = session.endedAt;
    if (endedAt == null) {
      return context.l10n.sessionOngoingLabel(start, duration);
    }
    return context.l10n.sessionRangeLabel(
      start,
      _clock(context, endedAt),
      duration,
    );
  }

  String _clock(BuildContext context, DateTime time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
