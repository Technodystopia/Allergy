import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../models.dart';
import '../services.dart';
import '../widgets.dart';

/// Calendar tier colours (match the timeline / reference pollen calendars):
/// peak = red, early/late = orange, possible = yellow.
const _tierColors = [
  null, // 0 = none (theme faint grey)
  Color(0xFFFDD835), // 1 possible
  Color(0xFFFB8C00), // 2 early/late
  Color(0xFFE53935), // 3 main flowering
];

class BloomScreen extends StatefulWidget {
  const BloomScreen({super.key});

  @override
  State<BloomScreen> createState() => _BloomScreenState();
}

class _BloomScreenState extends State<BloomScreen> {
  bool _calendar = false; // false = timeline, true = compact calendar
  bool _showAll = false; // false = my allergens, true = all

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final now = DateTime.now();
    final list =
        _showAll ? state.catalog.allergens : state.selectedAllergens;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // View + scope toggles.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false,
                        label: Text(s.bloomTimeline),
                        icon: const Icon(Icons.timeline, size: 16)),
                    ButtonSegment(
                        value: true,
                        label: Text(s.bloomCalendar),
                        icon: const Icon(Icons.calendar_view_month, size: 16)),
                  ],
                  selected: {_calendar},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) =>
                      setState(() => _calendar = v.first),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(s.bloomMine),
                selected: !_showAll,
                onSelected: (_) => setState(() => _showAll = false),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: Text(s.bloomAll),
                selected: _showAll,
                onSelected: (_) => setState(() => _showAll = true),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(s.noAllergens, textAlign: TextAlign.center),
          )
        else if (_calendar) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.calendarHeader,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          _CalendarGrid(allergens: list, now: now),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.bloomHeader),
          ),
          ...list.map((a) => _BloomCard(allergen: a, now: now)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// --- Compact calendar grid -------------------------------------------------

class _CalendarGrid extends StatelessWidget {
  final List<Allergen> allergens;
  final DateTime now;
  const _CalendarGrid({required this.allergens, required this.now});

  static const _labelW = 88.0;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().s;
    final faint = Colors.grey.withValues(alpha: 0.15);
    final thisMonth = now.month;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header row.
            Row(
              children: [
                const SizedBox(width: _labelW),
                ...List.generate(12, (i) {
                  final m = i + 1;
                  final current = m == thisMonth;
                  return Expanded(
                    child: Center(
                      child: Text(
                        s.monthAbbr(m),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              current ? FontWeight.bold : FontWeight.normal,
                          color: current
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 4),
            ...allergens.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _labelW,
                        child: Text(
                          '${a.emoji} ${s.allergenName(a).split(' · ').first}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...List.generate(12, (i) {
                        final m = i + 1;
                        final tier = a.season.tierForMonth(m);
                        final color = _tierColors[tier] ?? faint;
                        final current = m == thisMonth;
                        return Expanded(
                          child: Container(
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              border: current
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 1.4)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            _CalendarLegend(s: s),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final L10n s;
  const _CalendarLegend({required this.s});

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, String label) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );

    return Wrap(
      runSpacing: 4,
      children: [
        swatch(_tierColors[3]!, s.calMain),
        swatch(_tierColors[2]!, s.calEarlyLate),
        swatch(_tierColors[1]!, s.calPossible),
      ],
    );
  }
}

// --- Detailed timeline card (unchanged) ------------------------------------

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
            Semantics(
              label: '${s.allergenName(allergen)}: ${s.stageLabel(stage)} — '
                  '${s.stageDesc(stage)}',
              child: _SeasonBar(
                  season: allergen.season,
                  now: now,
                  color: allergen.thresholds
                      .levelFor(allergen.thresholds.high)
                      .color),
            ),
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
            if (allergen.kasviatlasUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AtlasLinkButton(allergen),
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
