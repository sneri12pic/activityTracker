import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/usage_item.dart';
import 'bubble_tooltip.dart';
import 'usage_bubble.dart';

class BubbleChart extends StatelessWidget {
  const BubbleChart({
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
    super.key,
  });

  final List<UsageItem> items;
  final UsageItem? selectedItem;
  final ValueChanged<UsageItem> onItemSelected;

  static const double _minRadius = 26;
  static const double _maxRadius = 72;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layout = _layoutItems(items, size);
          final selectedLayout = layout.cast<_BubbleLayout?>().firstWhere(
            (bubble) => bubble?.item.id == selectedItem?.id,
            orElse: () => null,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _ScaleRingPainter())),
              for (final bubble in layout)
                Positioned(
                  left: bubble.center.dx - bubble.radius,
                  top: bubble.center.dy - bubble.radius,
                  child: UsageBubble(
                    item: bubble.item,
                    radius: bubble.radius,
                    isSelected: bubble.item.id == selectedItem?.id,
                    onTap: () => onItemSelected(bubble.item),
                  ),
                ),
              if (selectedLayout != null)
                Positioned(
                  left: _clamp(
                    selectedLayout.center.dx - 82,
                    8,
                    size.width - 172,
                  ),
                  top: _tooltipTop(selectedLayout, size.height),
                  width: 164,
                  child: BubbleTooltip(item: selectedLayout.item),
                ),
            ],
          );
        },
      ),
    );
  }

  List<_BubbleLayout> _layoutItems(List<UsageItem> items, Size size) {
    if (items.isEmpty) {
      return const <_BubbleLayout>[];
    }

    final maxSeconds = items
        .map((item) => item.totalDurationSeconds)
        .reduce(math.max)
        .toDouble();
    final minDimension = math.min(size.width, size.height);
    final spread = minDimension * 0.31;
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final maxRadius = math.min(_maxRadius, minDimension * 0.2);

    return [
      for (var index = 0; index < items.length; index++)
        _BubbleLayout(
          item: items[index],
          radius: _radiusFor(items[index], maxSeconds, maxRadius),
          center: _centerFor(index, center, spread, size),
        ),
    ];
  }

  double _radiusFor(UsageItem item, double maxSeconds, double maxRadius) {
    if (maxSeconds <= 0) {
      return _minRadius;
    }
    final normalized = item.totalDurationSeconds / maxSeconds;
    return _minRadius + normalized * (maxRadius - _minRadius);
  }

  Offset _centerFor(int index, Offset center, double spread, Size size) {
    const offsets = [
      Offset(0, 0),
      Offset(-0.54, -0.06),
      Offset(0.5, 0.06),
      Offset(0.05, -0.55),
      Offset(-0.12, 0.54),
      Offset(-0.58, 0.46),
      Offset(0.6, -0.44),
      Offset(0.66, 0.42),
      Offset(-0.65, -0.46),
      Offset(0.24, 0.68),
    ];
    final template = offsets[index % offsets.length];
    final ring = index ~/ offsets.length;
    final ringSpread = spread + ring * 44;
    final dx = center.dx + template.dx * ringSpread;
    final dy = center.dy + template.dy * ringSpread;
    return Offset(
      _clamp(dx, 34, size.width - 34),
      _clamp(dy, 34, size.height - 34),
    );
  }

  double _tooltipTop(_BubbleLayout layout, double height) {
    final below = layout.center.dy + layout.radius + 10;
    if (below + 120 <= height) {
      return below;
    }
    return math.max(8, layout.center.dy - layout.radius - 124);
  }
}

class _BubbleLayout {
  const _BubbleLayout({
    required this.item,
    required this.radius,
    required this.center,
  });

  final UsageItem item;
  final double radius;
  final Offset center;
}

class _ScaleRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final maxRadius = math.min(size.width, size.height) * 0.48;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (final factor in const [0.36, 0.62, 0.88]) {
      canvas.drawCircle(center, maxRadius * factor, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _clamp(double value, double min, double max) {
  return value.clamp(min, math.max(min, max)).toDouble();
}
