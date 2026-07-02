import 'package:flutter/material.dart';

import '../../application/utils/duration_format.dart';
import '../../domain/models/usage_item.dart';

class BubbleTooltip extends StatelessWidget {
  const BubbleTooltip({required this.item, super.key});

  final UsageItem item;

  @override
  Widget build(BuildContext context) {
    final percentage = (item.percentageOfTotal * 100).clamp(0, 100);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151A24).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DurationFormat.compact(item.totalDuration),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${percentage.toStringAsFixed(0)}% of today',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
              ),
              const SizedBox(height: 2),
              Text(
                item.category,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
