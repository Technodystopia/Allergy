import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models.dart';

/// Small coloured pill showing a pollen level (localised).
class LevelBadge extends StatelessWidget {
  final PollenLevel level;
  final bool estimated;
  const LevelBadge(this.level, {super.key, this.estimated = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: estimated ? 0.45 : 1.0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estimated ? '${s.level(level)}${s.estSuffix}' : s.level(level),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Relevance chip for the Finnish context (very_high … none).
class RelevanceChip extends StatelessWidget {
  final String relevance;
  const RelevanceChip(this.relevance, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Chip(
      label: Text(s.relevance(relevance), style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
