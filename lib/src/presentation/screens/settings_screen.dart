import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_language.dart';
import '../localization/app_localizations_x.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final appLanguageState = ref.watch(appLanguageViewModelProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
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
                    l10n.settingsPrivacyTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.settingsPrivacyBody),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final confirmed = await _confirmClearData(context);
                            if (confirmed && context.mounted) {
                              await viewModel.clearLocalData();
                              await ref
                                  .read(appLanguageViewModelProvider.notifier)
                                  .restoreAfterDataClear();
                              await ref
                                  .read(restrictionsViewModelProvider.notifier)
                                  .load();
                              ref
                                  .read(dashboardViewModelProvider.notifier)
                                  .refresh();
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.settingsClearLocalData),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.settingsLanguageTitle),
                  subtitle: Text(
                    _languageName(context, appLanguageState.language),
                  ),
                  trailing: appLanguageState.isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: appLanguageState.isLoading || appLanguageState.isSaving
                      ? null
                      : () => _showLanguageDialog(
                          context,
                          ref,
                          appLanguageState.language,
                        ),
                ),
                if (appLanguageState.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.settingsLanguageUpdateError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
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
                    l10n.settingsExcludedAppsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.excludedApps.isEmpty)
                    Text(l10n.settingsExcludedAppsEmpty)
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
                          tooltip: l10n.settingsStopExcluding,
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
              label: Text(l10n.settingsWindowsTrackingComingSoon),
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
                      title: l10n.settingsWindowsTrackingInterval,
                      subtitle: l10n.secondsCount(
                        state.trackingIntervalSeconds,
                      ),
                      value: state.trackingIntervalSeconds,
                      min: 1,
                      max: 3600,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    _NumberSettingTile(
                      title: l10n.settingsWindowsIdleTimeout,
                      subtitle: l10n.secondsCount(state.idleTimeoutSeconds),
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
              l10n.commonUnexpectedError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    AppLanguage currentLanguage,
  ) async {
    final selectedLanguage = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.l10n.settingsChooseLanguage),
          contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: language,
                    groupValue: currentLanguage,
                    title: Text(_languageName(dialogContext, language)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged: (selection) {
                      Navigator.of(dialogContext).pop(selection);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.settingsCancel),
            ),
          ],
        );
      },
    );

    if (selectedLanguage == null || !context.mounted) {
      return;
    }
    await ref
        .read(appLanguageViewModelProvider.notifier)
        .updateLanguage(selectedLanguage);
  }

  String _languageName(BuildContext context, AppLanguage language) {
    return switch (language) {
      AppLanguage.system => context.l10n.settingsLanguageSystemDefault,
      AppLanguage.english => 'English',
      AppLanguage.spanish => 'Español',
      AppLanguage.french => 'Français',
      AppLanguage.german => 'Deutsch',
      AppLanguage.portugueseBrazil => 'Português (Brasil)',
      AppLanguage.japanese => '日本語',
      AppLanguage.ukrainian => 'Українська',
    };
  }

  Future<bool> _confirmClearData(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(context.l10n.settingsClearDataDialogTitle),
              content: Text(context.l10n.settingsClearDataDialogBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.settingsClear),
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
          Text(context.l10n.secondsCount(_value.round())),
          Slider(
            value: _value.clamp(widget.min.toDouble(), widget.max.toDouble()),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            divisions: 20,
            label: context.l10n.secondsCount(_value.round()),
            onChanged: (value) => setState(() => _value = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settingsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value.round()),
          child: Text(context.l10n.settingsSave),
        ),
      ],
    );
  }
}
