import 'package:flutter/material.dart';

/// The small rounded number shown next to a word or category:
/// how many videos are already recorded. Grey when 0, coloured otherwise.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasVideos = count > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasVideos ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: hasVideos ? colors.onPrimary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
