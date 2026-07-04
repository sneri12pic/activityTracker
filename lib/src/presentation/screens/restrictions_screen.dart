import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/utils/duration_format.dart';
import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/restriction_rule.dart';
import '../../domain/models/usage_session.dart';
import '../providers.dart';
import 'restriction_editor_sheet.dart';

class RestrictionsScreen extends ConsumerWidget {
  const RestrictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restrictionsViewModelProvider);
    final viewModel = ref.read(restrictionsViewModelProvider.notifier);
    final summaries = ref.watch(dashboardViewModelProvider).summaries;
    final usageByApp = {
      for (final summary in summaries) summary.appKey: summary,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restrictions'),
        actions: [
          IconButton(
            tooltip: 'Search apps',
            onPressed: () => _chooseAppAndCreateRule(
              context,
              ref,
              summaries: summaries,
              rules: state.rules,
            ),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _chooseAppAndCreateRule(
                context,
                ref,
                summaries: summaries,
                rules: state.rules,
              ),
              icon: const Icon(Icons.search),
              label: const Text('Add restriction'),
            ),
            const SizedBox(height: 12),
            if (state.platform == UsagePlatform.android &&
                !state.hasOverlayPermission) ...[
              _OverlayPermissionCard(
                onOpenSettings: viewModel.openOverlaySettings,
                onRecheck: viewModel.refreshOverlayPermission,
              ),
              const SizedBox(height: 12),
            ],
            if (state.platform != UsagePlatform.android) ...[
              const _InfoCard(
                title: 'Status only on this platform',
                body:
                    'Rules are saved and shown here. Full-screen blocking currently runs only on Android.',
              ),
              const SizedBox(height: 12),
            ],
            if (state.errorMessage != null) ...[
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.rules.isEmpty)
              const _InfoCard(
                title: 'No app restrictions',
                body:
                    'Long-press an app in the usage bubbles or current list to add a rule.',
              )
            else
              for (final rule in state.rules)
                _RestrictionRuleTile(
                  rule: rule,
                  summary: usageByApp[rule.appKey],
                  isSaving: state.isSaving,
                  onUnblockNow: () => viewModel.unblockAppNow(
                    appKey: rule.appKey,
                    usageSecondsToday:
                        usageByApp[rule.appKey]?.totalDurationSeconds ?? 0,
                  ),
                  onTap: () async {
                    final updated = await showRestrictionEditor(
                      context,
                      appKey: rule.appKey,
                      appName: rule.appName,
                      existing: rule,
                    );
                    if (updated == null || !context.mounted) {
                      return;
                    }
                    await viewModel.saveRule(updated);
                    if (context.mounted) {
                      await promptRestrictionPermissionsIfNeeded(context, ref);
                    }
                  },
                  onDelete: () => viewModel.deleteRule(rule.appKey, rule.type),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAppAndCreateRule(
    BuildContext context,
    WidgetRef ref, {
    required List<AppUsageSummary> summaries,
    required List<RestrictionRule> rules,
  }) async {
    final candidates = _appCandidates(summaries, rules);
    final selected = await showModalBottomSheet<_AppCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D111A),
      builder: (context) => _AppSearchSheet(candidates: candidates),
    );
    if (selected == null || !context.mounted) {
      return;
    }

    final rule = await showRestrictionEditor(
      context,
      appKey: selected.appKey,
      appName: selected.appName,
    );
    if (rule == null || !context.mounted) {
      return;
    }
    await ref.read(restrictionsViewModelProvider.notifier).saveRule(rule);
    if (context.mounted) {
      await promptRestrictionPermissionsIfNeeded(context, ref);
    }
  }

  List<_AppCandidate> _appCandidates(
    List<AppUsageSummary> summaries,
    List<RestrictionRule> rules,
  ) {
    final candidatesByKey = <String, _AppCandidate>{};
    for (final summary in summaries) {
      candidatesByKey[summary.appKey] = _AppCandidate(
        appKey: summary.appKey,
        appName: summary.appName,
        subtitle: summary.processName ?? summary.packageName,
        iconBytes: summary.iconBytes,
      );
    }
    for (final rule in rules) {
      candidatesByKey.putIfAbsent(
        rule.appKey,
        () => _AppCandidate(
          appKey: rule.appKey,
          appName: rule.appName,
          subtitle: rule.appKey,
        ),
      );
    }
    final candidates = candidatesByKey.values.toList()
      ..sort(
        (first, second) =>
            first.appName.toLowerCase().compareTo(second.appName.toLowerCase()),
      );
    return candidates;
  }
}

class _AppCandidate {
  const _AppCandidate({
    required this.appKey,
    required this.appName,
    this.subtitle,
    this.iconBytes,
  });

  final String appKey;
  final String appName;
  final String? subtitle;
  final List<int>? iconBytes;
}

class _AppSearchSheet extends StatefulWidget {
  const _AppSearchSheet({required this.candidates});

  final List<_AppCandidate> candidates;

  @override
  State<_AppSearchSheet> createState() => _AppSearchSheetState();
}

class _AppSearchSheetState extends State<_AppSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCandidates();
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search apps',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: widget.candidates.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No apps available yet. Open the dashboard after usage data is available, then search here.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matching apps'),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final candidate = filtered[index];
                          return ListTile(
                            leading: _AppIcon(candidate: candidate),
                            title: Text(
                              candidate.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: candidate.subtitle == null
                                ? null
                                : Text(
                                    candidate.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.of(context).pop(candidate),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_AppCandidate> _filteredCandidates() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.candidates;
    }
    return widget.candidates
        .where(
          (candidate) =>
              candidate.appName.toLowerCase().contains(query) ||
              candidate.appKey.toLowerCase().contains(query) ||
              (candidate.subtitle?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.candidate});

  final _AppCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final iconBytes = candidate.iconBytes;
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
        candidate.appName.isEmpty ? '?' : candidate.appName[0].toUpperCase(),
      ),
    );
  }
}

class _RestrictionRuleTile extends StatelessWidget {
  const _RestrictionRuleTile({
    required this.rule,
    required this.summary,
    required this.isSaving,
    required this.onUnblockNow,
    required this.onTap,
    required this.onDelete,
  });

  final RestrictionRule rule;
  final AppUsageSummary? summary;
  final bool isSaving;
  final VoidCallback onUnblockNow;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final usageSeconds = summary?.totalDurationSeconds ?? 0;
    final isBlocked = rule.blocksAt(DateTime.now(), usageSeconds);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: Icon(_iconFor(rule.type)),
            title: Text(
              rule.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_statusText(rule, summary)),
            onTap: onTap,
            trailing: IconButton(
              tooltip: 'Delete rule',
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: isSaving ? null : onUnblockNow,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Unblock now'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusText(RestrictionRule rule, AppUsageSummary? summary) {
    final now = DateTime.now();
    final usageSeconds = summary?.totalDurationSeconds ?? 0;
    final blockedUntil = rule.blockedUntil(
      now,
      usageSecondsToday: usageSeconds,
    );
    if (blockedUntil != null) {
      return 'Blocked until ${_clock(blockedUntil)}';
    }

    switch (rule.type) {
      case RestrictionRuleType.blockNow:
        return 'Temporary block expired';
      case RestrictionRuleType.dailyLimit:
        final used = DurationFormat.compact(Duration(seconds: usageSeconds));
        return 'Daily limit ${rule.limitMinutes ?? 0} min · $used used';
      case RestrictionRuleType.schedule:
        return 'Schedule ${_minuteClock(rule.startMinute)}-${_minuteClock(rule.endMinute)}';
    }
  }

  IconData _iconFor(RestrictionRuleType type) {
    switch (type) {
      case RestrictionRuleType.blockNow:
        return Icons.lock_clock_outlined;
      case RestrictionRuleType.dailyLimit:
        return Icons.timer_outlined;
      case RestrictionRuleType.schedule:
        return Icons.bedtime_outlined;
    }
  }

  String _clock(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _minuteClock(int? minute) {
    if (minute == null) {
      return '--:--';
    }
    final hours = (minute ~/ 60).toString().padLeft(2, '0');
    final minutes = (minute % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _OverlayPermissionCard extends StatelessWidget {
  const _OverlayPermissionCard({
    required this.onOpenSettings,
    required this.onRecheck,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overlay permission required',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Android needs Display over other apps permission before FocusTrace can show a block screen.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Overlay Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: onRecheck,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recheck'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

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
