import 'package:flutter/material.dart';

import '../../application/utils/duration_format.dart';
import '../../domain/models/app_usage_summary.dart';

class SummaryTile extends StatelessWidget {
  const SummaryTile(this.summary, {super.key});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (summary.percentageOfTotal * 100).clamp(0, 100);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(
                    summary.appName.isEmpty
                        ? '?'
                        : summary.appName[0].toUpperCase(),
                  ),
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
                      if (summary.processName != null ||
                          summary.packageName != null)
                        Text(
                          summary.processName ?? summary.packageName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      DurationFormat.compact(summary.totalDuration),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
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
    );
  }
}
