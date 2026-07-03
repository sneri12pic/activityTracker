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
    final maxRadius = math.min(_maxRadius, minDimension * 0.2);
    final radii = [
      for (final item in items) _radiusFor(item, maxSeconds, maxRadius),
    ];
    final centers = packBubbles(radii, size);

    return [
      for (var index = 0; index < items.length; index++)
        _BubbleLayout(
          item: items[index],
          radius: radii[index],
          center: centers[index],
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

const double _goldenAngle = 2.399963;

/// Iterative circle packing: every bubble is pulled toward the center while
/// colliding pairs push apart, with the displacement split by mass (radius²),
/// so the heaviest bubbles claim the middle and light ones get pushed out.
/// Deterministic — same radii always produce the same layout.
List<Offset> packBubbles(List<double> radii, Size size) {
  final center = Offset(size.width / 2, size.height / 2 + 10);
  // Radii arrive sorted biggest-first; seed on a small spiral so the biggest
  // starts (and stays) closest to the center.
  final positions = [
    for (var i = 0; i < radii.length; i++)
      center + Offset.fromDirection(i * _goldenAngle, 10.0 + 14.0 * i),
  ];

  final maxRadius = radii.reduce(math.max);

  // ponytail: fixed 150 relaxation steps for <=10 bubbles; converges long before that.
  for (var step = 0; step < 150; step++) {
    // Gravity fades out so late steps purely resolve collisions, and it is
    // mass-weighted so heavy bubbles pull to the center harder than light ones.
    final gravity = 0.04 * (1 - step / 150);
    for (var i = 0; i < positions.length; i++) {
      final weight = (radii[i] * radii[i]) / (maxRadius * maxRadius);
      positions[i] += (center - positions[i]) * (gravity * (0.2 + 0.8 * weight));
    }
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        var delta = positions[j] - positions[i];
        var distance = delta.distance;
        final minDistance = radii[i] + radii[j] + 4;
        if (distance >= minDistance) {
          continue;
        }
        if (distance < 0.01) {
          delta = Offset.fromDirection(j * _goldenAngle, 0.01);
          distance = 0.01;
        }
        final direction = delta / distance;
        final overlap = minDistance - distance;
        final massI = radii[i] * radii[i];
        final massJ = radii[j] * radii[j];
        positions[i] -= direction * (overlap * massJ / (massI + massJ));
        positions[j] += direction * (overlap * massI / (massI + massJ));
      }
    }
    for (var i = 0; i < positions.length; i++) {
      positions[i] = Offset(
        _clamp(positions[i].dx, radii[i], size.width - radii[i]),
        _clamp(positions[i].dy, radii[i], size.height - radii[i]),
      );
    }
  }
  return positions;
}
