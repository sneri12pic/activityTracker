import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../view_models/usage_bubble_view_model.dart';
import '../widgets/bubble_chart.dart';
import '../widgets/summary_tile.dart';

class UsageBubbleScreen extends ConsumerWidget {
  const UsageBubbleScreen({required this.summaries, super.key});

  final List<AppUsageSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usageBubbleViewModelProvider);
    final viewModel = ref.read(usageBubbleViewModelProvider.notifier);
    final items = viewModel.itemsFor(summaries);
    final selectedItem = viewModel.selectedItemFor(items, state.selectedItemId);

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BC0EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Column(
            children: [
              _SectionCard(
                children: [
                  Text(
                    'Usage Bubbles',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bigger bubbles mean more time spent',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  BubbleChart(
                    items: items,
                    selectedItem: selectedItem,
                    onItemSelected: viewModel.selectItem,
                    onSelectionDismissed: viewModel.clearSelection,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                children: [
                  Text(
                    'Current list',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final summary in summaries) SummaryTile(summary),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
