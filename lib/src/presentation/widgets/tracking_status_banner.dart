import 'package:flutter/material.dart';

import '../../domain/models/tracking_status.dart';
import '../../domain/models/usage_session.dart';

class TrackingStatusBanner extends StatelessWidget {
  const TrackingStatusBanner({required this.status, super.key});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = status.errorMessage != null;
    final color = isError
        ? theme.colorScheme.errorContainer
        : status.isTracking
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : status.isTracking
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : status.isTracking
                ? Icons.play_circle
                : Icons.info_outline,
            color: textColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.errorMessage ?? _labelFor(status),
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(TrackingStatus status) {
    if (status.platform == UsagePlatform.windows) {
      return status.isTracking
          ? 'Windows tracking is running while FocusTrace is open.'
          : 'Windows tracking runs only while FocusTrace is open.';
    }
    if (status.platform == UsagePlatform.android) {
      return 'Android usage is read from Usage Access.';
    }
    return 'Usage tracking is not supported on this platform yet.';
  }
}
