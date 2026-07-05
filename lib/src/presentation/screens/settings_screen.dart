import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'restrictions_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FocusTrace stores usage data locally on this device. It does not upload tracked app or window usage.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final confirmed = await _confirmClearData(context);
                            if (confirmed && context.mounted) {
                              await viewModel.clearLocalData();
                              await ref
                                  .read(restrictionsViewModelProvider.notifier)
                                  .load();
                              ref
                                  .read(dashboardViewModelProvider.notifier)
                                  .refresh();
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Local Data'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('App restrictions'),
              subtitle: const Text(
                'Block apps now, by daily limit, or schedule',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RestrictionsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Excluded apps',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.excludedApps.isEmpty)
                    const Text(
                      'No excluded apps. Long-press an app on the dashboard to exclude it from tracking.',
                    )
                  else
                    for (final appKey in state.excludedApps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          appKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Stop excluding',
                          icon: const Icon(Icons.undo),
                          onPressed: state.isSaving
                              ? null
                              : () async {
                                  await viewModel.removeExcludedApp(appKey);
                                  ref
                                      .read(dashboardViewModelProvider.notifier)
                                      .refresh();
                                },
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Chip(
              avatar: const Icon(Icons.hourglass_top, size: 18),
              label: const Text('Coming soon : Windows Tracking'),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          // ponytail: settings disabled for Play release, unblur when Windows sync ships
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Card(
                elevation: 0,
                child: Column(
                  children: [
                    _NumberSettingTile(
                      title: 'Windows tracking interval',
                      subtitle: '${state.trackingIntervalSeconds} seconds',
                      value: state.trackingIntervalSeconds,
                      min: 1,
                      max: 3600,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    _NumberSettingTile(
                      title: 'Windows idle timeout',
                      subtitle: '${state.idleTimeoutSeconds} seconds',
                      value: state.idleTimeoutSeconds,
                      min: 5,
                      max: 86400,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmClearData(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Clear local data?'),
              content: const Text(
                'This removes stored usage sessions and settings from this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _NumberSettingTile extends StatelessWidget {
  const _NumberSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final selected = await showDialog<int>(
          context: context,
          builder: (context) => _NumberSettingDialog(
            title: title,
            value: value,
            min: min,
            max: max,
          ),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class _NumberSettingDialog extends StatefulWidget {
  const _NumberSettingDialog({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
  });

  final String title;
  final int value;
  final int min;
  final int max;

  @override
  State<_NumberSettingDialog> createState() => _NumberSettingDialogState();
}

class _NumberSettingDialogState extends State<_NumberSettingDialog> {
  late double _value = widget.value.toDouble();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_value.round()} seconds'),
          Slider(
            value: _value.clamp(widget.min.toDouble(), widget.max.toDouble()),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            divisions: 20,
            label: '${_value.round()}s',
            onChanged: (value) => setState(() => _value = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value.round()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
