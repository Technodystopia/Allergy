import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services.dart';
import '../widgets.dart';

class BloomScreen extends StatelessWidget {
  const BloomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final allergens = state.selectedAllergens;
    final now = DateTime.now();

    if (allergens.isEmpty) {
      return Center(child: Text(s.noAllergens, textAlign: TextAlign.center));
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.bloomHeader),
        ),
        ...allergens.map((a) => _BloomCard(allergen: a, now: now)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BloomCard extends StatelessWidget {
  final Allergen allergen;
  final DateTime now;
  const _BloomCard({required this.allergen, required this.now});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final stage = Seasonal.stageFor(allergen, now);

    // Live "right now" status from the forecast, if available for today.
    final today = DateTime(now.year, now.month, now.day);
    DailyPollen? liveToday;
    for (final d in state.forecastFor(allergen.id)) {
      if (d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day) {
        liveToday = d;
      }
    }
    final hasLive = liveToday != null;
    final nowPeak = hasLive
        ? liveToday.peak
        : Seasonal.estimatePeak(allergen, now);
    final nowLevel = allergen.thresholds.levelFor(nowPeak);
    final level = stage == BloomStage.peak
        ? PollenLevel.high
        : (stage == BloomStage.onset || stage == BloomStage.declining)
            ? PollenLevel.moderate
            : PollenLevel.none;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(allergen.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.allergenName(allergen),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: level.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(s.stageLabel(stage),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SeasonBar(season: allergen.season, now: now, color: allergen.thresholds.levelFor(allergen.thresholds.high).color),
            const SizedBox(height: 6),
            const _MonthLabels(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${s.bloomNow}:',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 8),
                LevelBadge(nowLevel, estimated: !hasLive),
                const SizedBox(width: 8),
                Text(
                  hasLive
                      ? '${s.grains(nowPeak.round())} · ${s.bloomLive}'
                      : s.bloomModelEst,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (allergen.season.localizedNote(s.isFi).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(allergen.season.localizedNote(s.isFi),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeasonBar extends StatelessWidget {
  final Season season;
  final DateTime now;
  final Color color;
  const _SeasonBar({required this.season, required this.now, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // fraction of the year (0..1) for the "now" marker
        final dayOfYear =
            now.difference(DateTime(now.year, 1, 1)).inDays.toDouble();
        final nowX = (dayOfYear / 365.0) * w;

        return SizedBox(
          height: 22,
          child: Stack(
            children: [
              Row(
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final inSeason =
                      month >= season.startMonth && month <= season.endMonth;
                  final inPeak = month >= season.peakStartMonth &&
                      month <= season.peakEndMonth;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: inPeak
                            ? color
                            : inSeason
                                ? color.withValues(alpha: 0.35)
                                : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
              Positioned(
                left: nowX.clamp(0, w - 2),
                top: -2,
                bottom: -2,
                child: Container(width: 2.5, color: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels();
  @override
  Widget build(BuildContext context) {
    const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ))
          .toList(),
    );
  }
}
