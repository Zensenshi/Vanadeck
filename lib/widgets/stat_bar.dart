import 'package:flutter/material.dart';

class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.currentValue,
    required this.maxValue,
    required this.percent,
    required this.color,
    this.compact = false,
  });

  final String label;
  final int currentValue;
  final int maxValue;
  final double percent;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0.0, 1.0).toDouble();
    final barHeight = compact ? 5.0 : 8.0;
    final gap = compact ? 3.0 : 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '$currentValue / $maxValue',
              style: compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        SizedBox(height: gap),
        ClipRRect(
          borderRadius: BorderRadius.circular(barHeight / 2),
          child: LinearProgressIndicator(
            value: clampedPercent,
            minHeight: barHeight,
            backgroundColor: Colors.black.withValues(alpha: 0.28),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
